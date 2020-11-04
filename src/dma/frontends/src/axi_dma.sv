module axi_dma #(

    parameter int unsigned DataWidth = -1,
    parameter int unsigned AddrWidth = -1,
    parameter int unsigned IdWidth = -1,
    parameter int unsigned AxReqFifoDepth = -1,
    parameter int unsigned TransFifoDepth = -1,
    parameter int unsigned BufferDepth = -1,
    parameter int unsigned DmaIdWidth = -1,
    parameter int unsigned CfgAddrWidth = -1,
    parameter int unsigned CfgDataWidth = -1,
    parameter int unsigned AxiDmaID     = -1,
    parameter bit DmaTracing = -1,
    parameter type axi_req_t = logic,
    parameter type axi_res_t = logic,
    parameter type cfg_req_t = logic,
    parameter type cfg_res_t = logic
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  axi_res_t axi_dma_res_i,
    output axi_req_t axi_dma_req_o,
    input  cfg_req_t cfg_req_i,
    output cfg_res_t cfg_res_o,
    output logic dma_busy_o,
    input  logic[DmaIdWidth-1:0] dma_id_i
);

    localparam int unsigned NumRegs = 7;
    localparam int unsigned NumBytesRegs = 8 * NumRegs;

    localparam logic [NumBytesRegs-1:0] Load = 
        ('h01 << 32) |
        ('hff << 40) |
        ('hff << 48);

    localparam logic [NumBytesRegs-1:0] ReadOnly = 
        ('hff << 32) |
        ('hff << 40) |
        ('hff << 48);

    typedef logic[  IdWidth-1:0] axi_id_t;
    typedef logic[AddrWidth-1:0] addr_t;
    typedef logic[          7:0] byte_t;

    /// 1D burst request
    typedef struct packed {
        axi_id_t            id;
        addr_t              src, dst, num_bytes;
        axi_pkg::cache_t    cache_src, cache_dst;
        axi_pkg::burst_t    burst_src, burst_dst;
        logic               decouple_rw;
        logic               deburst;
    } burst_req_t;

    typedef struct packed {
        logic[63:0] start_tf;
        logic[63:0] last_id;
        logic[62:0] pad_status;
        logic       status;
        logic[53:0] pad_config;
        logic[ 3:0] cache_dst;
        logic[ 3:0] cache_src;
        logic       deburst;
        logic       decouple_rw;
        logic[63:0] dst_addr; 
        logic[63:0] src_addr;      
        logic[63:0] num_bytes;      
    } dma_conf_t;

    typedef union packed {
        dma_conf_t dma;
        byte_t [NumRegs*8-1:0] mem;
    } dma_conf_union_t;

    burst_req_t burst_req;
    dma_conf_union_t dma_conf_d, dma_conf_q;

    logic tf_valid, tf_ready;

    cfg_req_t cfg_req;
    cfg_res_t cfg_res;

    logic [NumRegs*8-1:0] rd_active;

    logic backend_idle;
    logic trans_complete;

    logic [31:0] next;
    logic [31:0] completed;


    axi_dma_backend #(
        .DataWidth       ( DataWidth       ),
        .AddrWidth       ( AddrWidth       ),
        .IdWidth         ( IdWidth         ),
        .AxReqFifoDepth  ( AxReqFifoDepth  ),
        .TransFifoDepth  ( TransFifoDepth  ),
        .BufferDepth     ( BufferDepth     ),
        .axi_req_t       ( axi_req_t       ),
        .axi_res_t       ( axi_res_t       ),
        .burst_req_t     ( burst_req_t     ),
        .DmaIdWidth      ( DmaIdWidth      ),
        .DmaTracing      ( DmaTracing      )
    ) i_axi_dma_backend (
        .clk_i            ( clk_i          ),
        .rst_ni           ( rst_ni         ),
        .axi_dma_req_o    ( axi_dma_req_o  ),
        .axi_dma_res_i    ( axi_dma_res_i  ),
        .burst_req_i      ( burst_req      ),
        .valid_i          ( tf_valid       ),
        .ready_o          ( tf_ready       ),
        .backend_idle_o   ( backend_idle   ),
        .trans_complete_o ( trans_complete ),
        .dma_id_i         ( dma_id_i       )
    );

    assign dma_busy_o = !backend_idle;

    always_comb begin : proc_block_bus
        cfg_req            = cfg_req_i;
        cfg_req.ar_valid   = cfg_req_i.ar_valid & tf_ready;
        cfg_res_o          = cfg_res;
        cfg_res_o.ar_ready = cfg_res.ar_ready & tf_ready;
    end

    axi_lite_regs #(
        .RegNumBytes  ( NumBytesRegs ),
        .AxiAddrWidth ( CfgAddrWidth ),
        .AxiDataWidth ( CfgDataWidth ),
        .AxiReadOnly  ( ReadOnly     ),
        .req_lite_t   ( cfg_req_t    ),
        .resp_lite_t  ( cfg_res_t    )
    ) i_axi_lite_regs (
        .clk_i        ( clk_i          ),
        .rst_ni       ( rst_ni         ),
        .axi_req_i    ( cfg_req        ),
        .axi_resp_o   ( cfg_res        ),
        .wr_active_o  ( ),
        .rd_active_o  ( rd_active      ),
        .reg_d_i      ( dma_conf_d.mem ),
        .reg_load_i   ( Load           ),
        .reg_q_o      ( dma_conf_q.mem )
    );

    assign tf_valid = |rd_active[55:48];

    transfer_id_gen #(
        .ID_WIDTH    ( 32         )
    ) i_transfer_id_gen (
        .clk_i       ( clk_i               ),
        .rst_ni      ( rst_ni              ),
        .issue_i     ( tf_valid & tf_ready ),
        .retire_i    ( trans_complete      ),
        .next_o      ( next                ),
        .completed_o ( completed           )
    );

    always_comb begin : proc_build_request




        dma_conf_d.mem = dma_conf_q.mem;

        dma_conf_d.dma.pad_config = '0; 
        dma_conf_d.dma.pad_status = '0; 

        dma_conf_d.dma.last_id  = completed;
        dma_conf_d.dma.start_tf = next;
        dma_conf_d.dma.status   = !backend_idle;

        // build config struct
        burst_req = '{
            id:           axi_id_t'(AxiDmaID),
            src:          addr_t'(dma_conf_q.dma.src_addr),
            dst:          addr_t'(dma_conf_q.dma.dst_addr),
            num_bytes:    addr_t'(dma_conf_q.dma.num_bytes),
            cache_src:    dma_conf_q.dma.cache_src,
            cache_dst:    dma_conf_q.dma.cache_dst,
            burst_src:    axi_pkg::BURST_INCR,
            burst_dst:    axi_pkg::BURST_INCR,
            decouple_rw:  dma_conf_q.dma.decouple_rw,
            deburst:      dma_conf_q.dma.deburst
        };
    
    end

endmodule : axi_dma
