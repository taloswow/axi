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
module axi_dc_src_wrap #(
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
  // slave side - clocked by `src_clk_i`
  input  logic      src_clk_i,
  input  logic      src_rst_ni,
  AXI_BUS.Slave     src,
  input  logic      isolate_i,
  output logic [LogDepth:0]      async_data_master_aw_wptr_o,
  input  logic [LogDepth:0]      async_data_master_aw_rptr_i,
  output AW_T [2**LogDepth-1:0]  async_data_master_aw_data_o,
  output logic [LogDepth:0]      async_data_master_w_wptr_o,
  input  logic [LogDepth:0]      async_data_master_w_rptr_i,
  output W_T [2**LogDepth-1:0]   async_data_master_w_data_o,
  output logic [LogDepth:0]      async_data_master_ar_wptr_o,
  input  logic [LogDepth:0]      async_data_master_ar_rptr_i,
  output AR_T [2**LogDepth-1:0]  async_data_master_ar_data_o,
  input  logic [LogDepth:0]      async_data_master_b_wptr_i,
  output logic [LogDepth:0]      async_data_master_b_rptr_o,
  input  B_T [2**LogDepth-1:0]   async_data_master_b_data_i,
  input  logic [LogDepth:0]      async_data_master_r_wptr_i,
  output logic [LogDepth:0]      async_data_master_r_rptr_o,
  input  R_T [2**LogDepth-1:0]   async_data_master_r_data_i
);

   `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)
   `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
   `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)
   `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t)
   `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t)
   `AXI_TYPEDEF_REQ_T(req_t, aw_chan_t, w_chan_t, ar_chan_t)
   `AXI_TYPEDEF_RESP_T(resp_t, b_chan_t, r_chan_t)
   req_t  src_req;
   resp_t src_resp;
   `AXI_ASSIGN_TO_REQ(src_req, src)
   `AXI_ASSIGN_FROM_RESP(src,src_resp)
 
   cdc_fifo_gray_src #(
        .T(logic [$bits(aw_chan_t)-1:0]),
        .LOG_DEPTH(LogDepth)
   ) cdc_fifo_gray_src_aw (
     .src_rst_ni   ( src_rst_ni                         ),
     .src_clk_i    ( src_clk_i                          ),
     .src_data_i   ( src_req.aw                         ),
     .src_valid_i  ( src_req.aw_valid & ~isolate_i      ),
     .src_ready_o  ( src_resp.aw_ready                  ),
     .async_data_o ( async_data_master_aw_data_o        ),
     .async_wptr_o ( async_data_master_aw_wptr_o        ),
     .async_rptr_i ( async_data_master_aw_rptr_i        )
   );
   

   cdc_fifo_gray_src #(
        .T(logic [$bits(w_chan_t)-1:0]),
        .LOG_DEPTH(LogDepth)
   ) cdc_fifo_gray_src_w (
     .src_rst_ni   ( src_rst_ni                         ),
     .src_clk_i    ( src_clk_i                          ),
     .src_data_i   ( src_req.w                          ),
     .src_valid_i  ( src_req.w_valid  & ~isolate_i      ),
     .src_ready_o  ( src_resp.w_ready                   ),
     .async_data_o ( async_data_master_w_data_o         ),
     .async_wptr_o ( async_data_master_w_wptr_o         ),
     .async_rptr_i ( async_data_master_w_rptr_i         )
   );


   cdc_fifo_gray_dst #(
        .T(logic [$bits(b_chan_t)-1:0]),
        .LOG_DEPTH(LogDepth)
   ) cdc_fifo_gray_dst_b (
     .dst_rst_ni   ( src_rst_ni                         ),
     .dst_clk_i    ( src_clk_i                          ),
     .dst_data_o   ( src_resp.b                         ),
     .dst_valid_o  ( src_resp.b_valid                   ),
     .dst_ready_i  ( src_req.b_ready  & ~isolate_i      ),
     .async_data_i ( async_data_master_b_data_i         ),
     .async_wptr_i ( async_data_master_b_wptr_i         ),
     .async_rptr_o ( async_data_master_b_rptr_o         )
   );


   cdc_fifo_gray_dst #(
        .T(logic [$bits(r_chan_t)-1:0]),
        .LOG_DEPTH(LogDepth)
   ) cdc_fifo_gray_dst_r (
     .dst_rst_ni   ( src_rst_ni                         ),
     .dst_clk_i    ( src_clk_i                          ),
     .dst_data_o   ( src_resp.r                         ),
     .dst_valid_o  ( src_resp.r_valid                   ),
     .dst_ready_i  ( src_req.r_ready  & ~isolate_i      ),
     .async_data_i ( async_data_master_r_data_i         ),
     .async_wptr_i ( async_data_master_r_wptr_i         ),
     .async_rptr_o ( async_data_master_r_rptr_o         )
   );

   cdc_fifo_gray_src #(
        .T(logic [$bits(ar_chan_t)-1:0]),
        .LOG_DEPTH(LogDepth)
   ) cdc_fifo_gray_src_ar (
     .src_rst_ni   ( src_rst_ni                         ),
     .src_clk_i    ( src_clk_i                          ),
     .src_data_i   ( src_req.ar                         ),
     .src_valid_i  ( src_req.ar_valid  & ~isolate_i     ),
     .src_ready_o  ( src_resp.ar_ready                  ),
     .async_data_o ( async_data_master_ar_data_o        ),
     .async_wptr_o ( async_data_master_ar_wptr_o        ),
     .async_rptr_i ( async_data_master_ar_rptr_i        )
   );
   
   
endmodule
