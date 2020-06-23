// Copyright 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Authors:
// - Wolfgang Rönninger <wroennin@iis.ee.ethz.ch>

/// AXI4-Lite data width downsize conversion module.
module axi_lite_dw_downsizer #(
  /// AXI4-Lite address width of the ports.
  parameter int unsigned AxiAddrWidth        = 32'd0,
  /// AXI4-Lite data width of the slave port.
  parameter int unsigned AxiSlvPortDataWidth = 32'd0,
  /// AXI4-Lite data width of the master port.
  parameter int unsigned AxiMstPortDataWidth = 32'd0
  /// AXI4-Lite request struct of the slave port.
  parameter type         axi_lite_slv_req_t  = logic,
  /// AXI4-Lite response struct of the slave port.
  parameter type         axi_lite_slv_res_t  = logic,
  /// AXI4-Lite request struct of the master port.
  parameter type         axi_lite_mst_req_t  = logic,
  /// AXI4-Lite response struct of the master port.
  parameter type         axi_lite_mst_res_t  = logic
) (
  /// Clock, positive edge triggered.
  input  logic               clk_i,
  /// Asynchrounous reset, active low.
  input  logic               rst_ni,
  /// Salve port, AXI4-Lite request.
  input  axi_lite_slv_req_t  slv_req_i,
  /// Salve port, AXI4-Lite response.
  output axi_lite_slv_res_t  slv_res_o,
  /// Master port, AXI4-Lite request.
  output axi_lite_mst_req_t  mst_req_o,
  /// Master port, AXI4-Lite response.
  input  axi_lite_mst_res_t  mst_res_i
);

  `include "axi/typedef.svh"






  // Assertions, check params
  // pragma translate_off
  `ifndef VERILATOR
  initial begin
    assume (AxiAddrWidth        > 0) else $fatal(1, "AXI address width has to be > 0");
    assume (AxiSlvPortDataWidth > 0) else $fatal(1, "AxiSlvPortDataWidth has to be > 0");
    assume (AxiMstPortDataWidth > 0) else $fatal(1, "AxiMstPortDataWidth has to be > 0");
    assume (AxiSlvPortDataWidth > AxiMstPortDataWidth) else
        $fatal(1, "AxiSlvPortDataWidth has to be > AxiMstPortDataWidth");
    assume ($onehot(AxiSlvPortDataWidth)) else $fatal(1, "AxiSlvPortDataWidth must be power of 2");
    assume ($onehot(AxiMstPortDataWidth)) else $fatal(1, "AxiMstPortDataWidth must be power of 2");
  end
  default disable iff (~rst_ni);
  stable_aw: assert property (@(posedge clk_i)
      (mst_req_o.aw_valid && !mst_res_i.aw_ready) |=> $stable(mst_req_o.aw)) else
      $fatal(1, "AW is unstable.");


  `endif
  // pragma translate_on
endmodule
