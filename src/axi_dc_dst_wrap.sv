// Copyright (c) 20192-2020 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Andreas Kurth <akurth@iis.ee.ethz.ch>
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// Luca Valente <luca.valente2@unibo.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"
/// A clock domain crossing on an AXI interface.
///
/// For each of the five AXI channels, this module instantiates a CDC FIFO, whose push and pop
/// ports are in separate clock domains.  IMPORTANT: For each AXI channel, you MUST properly
/// constrain three paths through the FIFO; see the header of `cdc_fifo_gray` for instructions.
module axi_dc_dst_wrap #(
  parameter AXI_ADDR_WIDTH  = 1, 
  parameter AXI_DATA_WIDTH  = 1,
  parameter AXI_USER_WIDTH  = 1,
  parameter AXI_ID_WIDTH    = 1,
  /// Depth of the FIFO crossing the clock domain, given as 2**LOG_DEPTH.
  parameter int unsigned  LogDepth  = 1,
  localparam type id_t   =  logic [AXI_ID_WIDTH-1:0],
  localparam type addr_t =  logic [AXI_ADDR_WIDTH-1:0],
  localparam type data_t =  logic [AXI_DATA_WIDTH-1:0],
  localparam type strb_t =  logic [AXI_DATA_WIDTH/8-1:0],
  localparam type user_t =  logic [AXI_USER_WIDTH-1:0],
  localparam type AW_T   =  logic [$bits(axi_pkg::len_t)+$bits(axi_pkg::size_t)+$bits(axi_pkg::burst_t)+$bits(axi_pkg::cache_t)+$bits(axi_pkg::prot_t)+$bits(axi_pkg::qos_t)+$bits(axi_pkg::region_t)+$bits(axi_pkg::atop_t)+$bits(id_t)+$bits(addr_t)+$bits(user_t)+1-1:0],
  localparam type W_T    =  logic [1+$bits(user_t)+$bits(strb_t)+$bits(data_t)-1:0],
  localparam type B_T    =  logic [$bits(user_t)+$bits(axi_pkg::resp_t)+$bits(id_t)-1:0],
  localparam type AR_T   =  logic [$bits(axi_pkg::len_t)+$bits(axi_pkg::size_t)+$bits(axi_pkg::burst_t)+$bits(axi_pkg::cache_t)+$bits(axi_pkg::prot_t)+$bits(axi_pkg::qos_t)+$bits(axi_pkg::region_t)+$bits(id_t)+$bits(addr_t)+$bits(user_t)+1-1:0],
  localparam type R_T    =  logic [$bits(axi_pkg::resp_t)+$bits(id_t)+$bits(data_t)+$bits(user_t)+1-1:0]
) (
  // master side - clocked by `dst_clk_i`
  input  logic      dst_clk_i,
  input  logic      dst_rst_ni,
  AXI_BUS.Master    dst,
  input  logic [LogDepth:0]      async_data_slave_aw_wptr_i,
  output logic [LogDepth:0]      async_data_slave_aw_rptr_o,
  input  AW_T [2**LogDepth-1:0]  async_data_slave_aw_data_i,
  input  logic [LogDepth:0]      async_data_slave_w_wptr_i,
  output logic [LogDepth:0]      async_data_slave_w_rptr_o,
  input  W_T [2**LogDepth-1:0]   async_data_slave_w_data_i,
  input  logic [LogDepth:0]      async_data_slave_ar_wptr_i,
  output logic [LogDepth:0]      async_data_slave_ar_rptr_o,
  input  AR_T [2**LogDepth-1:0]  async_data_slave_ar_data_i,
  output logic [LogDepth:0]      async_data_slave_b_wptr_o,
  input  logic [LogDepth:0]      async_data_slave_b_rptr_i,
  output B_T [2**LogDepth-1:0]   async_data_slave_b_data_o,
  output logic [LogDepth:0]      async_data_slave_r_wptr_o,
  input  logic [LogDepth:0]      async_data_slave_r_rptr_i,
  output R_T [2**LogDepth-1:0]   async_data_slave_r_data_o
);

   `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)
   `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
   `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)
   `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t)
   `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t)
   `AXI_TYPEDEF_REQ_T(req_t, aw_chan_t, w_chan_t, ar_chan_t)
   `AXI_TYPEDEF_RESP_T(resp_t, b_chan_t, r_chan_t)
   req_t  dst_req;
   resp_t dst_resp;
   `AXI_ASSIGN_FROM_REQ(dst,dst_req)
   `AXI_ASSIGN_TO_RESP(dst_resp,dst)
   
    cdc_fifo_gray_dst #(
        .T(logic [$bits(aw_chan_t)-1:0]),
        .LOG_DEPTH(LogDepth)
    ) cdc_fifo_gray_dst_aw (
        .dst_rst_ni           ( dst_rst_ni                   ),
        .dst_clk_i            ( dst_clk_i                    ),
        .dst_data_o           ( dst_req.aw                   ),
        .dst_valid_o          ( dst_req.aw_valid             ),
        .dst_ready_i          ( dst_resp.aw_ready            ),
        .async_data_i         ( async_data_slave_aw_data_i   ),
        .async_wptr_i         ( async_data_slave_aw_wptr_i   ),
        .async_rptr_o         ( async_data_slave_aw_rptr_o   )
    );


   cdc_fifo_gray_dst #(
        .T(logic [$bits(w_chan_t)-1:0]),
        .LOG_DEPTH(LogDepth)
    ) cdc_fifo_gray_dst_w (
        .dst_rst_ni           ( dst_rst_ni                   ),
        .dst_clk_i            ( dst_clk_i                    ),
        .dst_data_o           ( dst_req.w                    ),
        .dst_valid_o          ( dst_req.w_valid              ),
        .dst_ready_i          ( dst_resp.w_ready             ),
        .async_data_i         ( async_data_slave_w_data_i    ),
        .async_wptr_i         ( async_data_slave_w_wptr_i    ),
        .async_rptr_o         ( async_data_slave_w_rptr_o    )
    );


   cdc_fifo_gray_src #(
        .T(logic [$bits(b_chan_t)-1:0]),
        .LOG_DEPTH(LogDepth)
    ) cdc_fifo_gray_src_b (
        .src_rst_ni           ( dst_rst_ni                    ),
        .src_clk_i            ( dst_clk_i                     ),
        .src_data_i           ( dst_resp.b                    ),
        .src_valid_i          ( dst_resp.b_valid              ),
        .src_ready_o          ( dst_req.b_ready               ),
        .async_data_o         ( async_data_slave_b_data_o     ),
        .async_wptr_o         ( async_data_slave_b_wptr_o     ),
        .async_rptr_i         ( async_data_slave_b_rptr_i     )
    );


   cdc_fifo_gray_src #(
        .T(logic [$bits(r_chan_t)-1:0]),
        .LOG_DEPTH(LogDepth)
    ) cdc_fifo_gray_src_r (
        .src_rst_ni           ( dst_rst_ni                    ),
        .src_clk_i            ( dst_clk_i                     ),
        .src_data_i           ( dst_resp.r                    ),
        .src_valid_i          ( dst_resp.r_valid              ),
        .src_ready_o          ( dst_req.r_ready               ),
        .async_data_o         ( async_data_slave_r_data_o     ),
        .async_wptr_o         ( async_data_slave_r_wptr_o     ),
        .async_rptr_i         ( async_data_slave_r_rptr_i     )
    );

   cdc_fifo_gray_dst #(
        .T(logic [$bits(ar_chan_t)-1:0]),
        .LOG_DEPTH(LogDepth)
    ) cdc_fifo_gray_dst_ar (
        .dst_rst_ni           ( dst_rst_ni                   ),
        .dst_clk_i            ( dst_clk_i                    ),
        .dst_data_o           ( dst_req.ar                   ),
        .dst_valid_o          ( dst_req.ar_valid             ),
        .dst_ready_i          ( dst_resp.ar_ready            ),
        .async_data_i         ( async_data_slave_ar_data_i   ),
        .async_wptr_i         ( async_data_slave_ar_wptr_i   ),
        .async_rptr_o         ( async_data_slave_ar_rptr_o   )
    );

endmodule
