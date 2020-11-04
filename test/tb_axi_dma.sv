`timescale 1ns/1ns
module tb_axi_dma;

    `include "axi/assign.svh"
    `include "axi/typedef.svh"

    //--------------------------------------
    // Parameters
    //-------------------------------------- 
    localparam TA           = 0.2ns;  // must be nonzero to avoid Snitch load fifo double pop glitch
    localparam TT           = 0.8ns;
    localparam HalfPeriod   = 50ns;
    localparam Reset        = 75ns;

    localparam DataWidth    = 512;
    localparam AddrWidth    = 64;
    localparam StrbWidth    = DataWidth / 8;
    localparam IdWidth      = 6;
    localparam UserWidth    = 1;

    localparam CfgDataWidth = 32;
    localparam CfgAddrWidth = 32;

    /// Address Type
    typedef logic [     AddrWidth-1:0] addr_t;
    /// Data Type
    typedef logic [     DataWidth-1:0] data_t;
    /// Strobe Type
    typedef logic [   DataWidth/8-1:0] strb_t;
    /// AXI ID Type
    typedef logic [       IdWidth-1:0] axi_id_t;
    /// AXI USER Type
    typedef logic [     UserWidth-1:0] user_t;
    /// Address Type
    typedef logic [  CfgAddrWidth-1:0] cfg_addr_t;
    /// Data Type
    typedef logic [  CfgDataWidth-1:0] cfg_data_t;
    /// Strobe Type
    typedef logic [CfgDataWidth/8-1:0] cfg_strb_t;

    typedef axi_test::rand_axi_slave #(
        .AW                   ( AddrWidth  ),
        .DW                   ( DataWidth  ),
        .IW                   ( IdWidth    ),
        .UW                   ( UserWidth  ),
        .TA                   ( TA         ),
        .TT                   ( TT         ),
        .AX_MIN_WAIT_CYCLES   ( 0          ), 
        .AX_MAX_WAIT_CYCLES   ( 0          ), 
        .R_MIN_WAIT_CYCLES    ( 0          ), 
        .R_MAX_WAIT_CYCLES    ( 0          ), 
        .RESP_MIN_WAIT_CYCLES ( 0          ), 
        .RESP_MAX_WAIT_CYCLES ( 0          ) 
    ) rand_axi_slave_t;

    //--------------------------------------
    // Clock and Reset
    //-------------------------------------- 
    logic clk;
    initial begin
        forever begin
            clk = 0;
            #HalfPeriod;
            clk = 1;
            #HalfPeriod;
        end
    end

    logic rst_n;
    initial begin
        cfg_axi_lite_drv.reset_master();
        rand_axi_slave.reset();
        rst_n = 0;
        #Reset;
        rst_n = 1;
    end

    //--------------------------------------
    // AXI / AXI Lite definitions
    //-------------------------------------- 
    `AXI_TYPEDEF_AW_CHAN_T(aw_chan_dma_t, addr_t, axi_id_t, user_t)
    `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
    `AXI_TYPEDEF_B_CHAN_T(b_chan_dma_t, axi_id_t, user_t)
    
    `AXI_TYPEDEF_AR_CHAN_T(ar_chan_dma_t, addr_t, axi_id_t, user_t)
    `AXI_TYPEDEF_R_CHAN_T(r_chan_dma_t, data_t, axi_id_t, user_t)
    
    `AXI_TYPEDEF_REQ_T(dma_req_t, aw_chan_dma_t, w_chan_t, ar_chan_dma_t)
    `AXI_TYPEDEF_RESP_T(dma_res_t, b_chan_dma_t, r_chan_dma_t)


    `AXI_LITE_TYPEDEF_AW_CHAN_T(aw_chan_cfg_t, cfg_addr_t)
    `AXI_LITE_TYPEDEF_W_CHAN_T(w_chan_cfg_t, cfg_data_t, cfg_strb_t)
    `AXI_LITE_TYPEDEF_B_CHAN_T(b_chan_cfg_t)

    `AXI_LITE_TYPEDEF_AR_CHAN_T(ar_chan_cfg_t, cfg_addr_t)
    `AXI_LITE_TYPEDEF_R_CHAN_T(r_chan_cfg_t, cfg_data_t)

    `AXI_LITE_TYPEDEF_REQ_T(cfg_req_t, aw_chan_cfg_t, w_chan_cfg_t, ar_chan_cfg_t)
    `AXI_LITE_TYPEDEF_RESP_T(cfg_res_t, b_chan_cfg_t, r_chan_cfg_t)


    cfg_res_t cfg_res;
    cfg_req_t cfg_req;

    AXI_LITE_DV #(
        .AXI_ADDR_WIDTH(CfgAddrWidth),
        .AXI_DATA_WIDTH(CfgDataWidth)
    ) cfg_axi_lite_dv(clk);

    AXI_LITE #(
        .AXI_ADDR_WIDTH(CfgAddrWidth),
        .AXI_DATA_WIDTH(CfgDataWidth)
    ) cfg_axi_lite();

    `AXI_LITE_ASSIGN(cfg_axi_lite, cfg_axi_lite_dv)

    `AXI_LITE_ASSIGN_TO_REQ(cfg_req, cfg_axi_lite)
    `AXI_LITE_ASSIGN_FROM_RESP(cfg_axi_lite, cfg_res)

    dma_req_t mem_req;
    dma_res_t mem_res;

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AddrWidth  ),
        .AXI_DATA_WIDTH ( DataWidth  ),
        .AXI_ID_WIDTH   ( IdWidth    ),
        .AXI_USER_WIDTH ( UserWidth  )
    ) mem ();
    AXI_BUS_DV #(
        .AXI_ADDR_WIDTH ( AddrWidth  ),
        .AXI_DATA_WIDTH ( DataWidth  ),
        .AXI_ID_WIDTH   ( IdWidth    ),
        .AXI_USER_WIDTH ( UserWidth  )
    ) mem_dv (clk);

    `AXI_ASSIGN(mem_dv, mem)

    `AXI_ASSIGN_TO_RESP(mem_res, mem)
    `AXI_ASSIGN_FROM_REQ(mem, mem_req)

    axi_test::axi_lite_driver #(.AW(CfgAddrWidth), .DW(CfgDataWidth), .TA(TA), .TT(TT)) cfg_axi_lite_drv = new(cfg_axi_lite_dv);
    static rand_axi_slave_t rand_axi_slave = new(mem_dv);

    //--------------------------------------
    // AXI DMA
    //-------------------------------------- 
    axi_dma #(
        .DataWidth      ( DataWidth    ),
        .AddrWidth      ( AddrWidth    ),
        .IdWidth        ( IdWidth      ),
        .AxiDmaID       ( 0            ),
        .AxReqFifoDepth ( 2            ),
        .TransFifoDepth ( 2            ),
        .BufferDepth    ( 3            ),
        .DmaIdWidth     ( 1            ),
        .CfgAddrWidth   ( CfgAddrWidth ),
        .CfgDataWidth   ( CfgDataWidth ),
        .DmaTracing     ( 1            ),
        .axi_req_t      ( dma_req_t    ),
        .axi_res_t      ( dma_res_t    ),
        .cfg_req_t      ( cfg_req_t    ),
        .cfg_res_t      ( cfg_res_t    )
    ) i_axi_dma (
        .clk_i          ( clk      ),
        .rst_ni         ( rst_n    ),
        .axi_dma_res_i  ( mem_res  ),
        .axi_dma_req_o  ( mem_req  ),
        .cfg_req_i      ( cfg_req  ),
        .cfg_res_o      ( cfg_res  ),
        .dma_id_i       ( '0       ),
        .dma_busy_o     ( busy     )
    );

    //--------------------------------------
    // Tests
    //-------------------------------------- 
    initial begin
        @(posedge rst_n);
       rand_axi_slave.run();
    end

    initial begin
        logic [1:0] resp;
        cfg_data_t data;
        @(posedge rst_n);
        @(posedge clk);
        #(200*HalfPeriod);

        fork
            cfg_axi_lite_drv.send_aw('d0, 0);
            cfg_axi_lite_drv.send_w ('d640000, 'hffff);
        join
            cfg_axi_lite_drv.recv_b(resp);

        fork
            cfg_axi_lite_drv.send_aw('d8, 0);
            cfg_axi_lite_drv.send_w ('d0, 'hffff);
        join
            cfg_axi_lite_drv.recv_b(resp);

        fork
            cfg_axi_lite_drv.send_aw('d16, 0);
            cfg_axi_lite_drv.send_w ('h1000, 'hffff);
        join
            cfg_axi_lite_drv.recv_b(resp);

        fork
            cfg_axi_lite_drv.send_ar('d48, 0);
            // cfg_axi_lite_drv.send_w ('hbeef, 'hff);
        join
            cfg_axi_lite_drv.recv_r(data, resp);

        #(50*HalfPeriod);

         fork
             cfg_axi_lite_drv.send_ar('d40, 0);
             // cfg_axi_lite_drv.send_w ('hbeef, 'hff);
         join
             cfg_axi_lite_drv.recv_r(data, resp);

        @(negedge busy);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

         fork
             cfg_axi_lite_drv.send_ar('d40, 0);
             // cfg_axi_lite_drv.send_w ('hbeef, 'hff);
         join
             cfg_axi_lite_drv.recv_r(data, resp);

        #(200*HalfPeriod);
        $stop();
    end

endmodule : tb_axi_dma
