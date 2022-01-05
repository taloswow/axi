// Copyright 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Matheus Cavalcante <matheusd@iis.ee.ethz.ch>

`include "axi/assign.svh"

module tb_axi_dw_upsizer_1 #(
    // AXI Parameters
    parameter int unsigned TbAxiAddrWidth        = 64  ,
    parameter int unsigned TbAxiIdWidth          = 4   ,
    parameter int unsigned TbAxiSlvPortDataWidth = 64  ,
    parameter int unsigned TbAxiMstPortDataWidth = 128 ,
    parameter int unsigned TbAxiUserWidth        = 8   ,
    // TB Parameters
    parameter time TbCyclTime                    = 10ns,
    parameter time TbApplTime                    = 2ns ,
    parameter time TbTestTime                    = 8ns
  );

  /*********************
   *  CLOCK GENERATOR  *
   *********************/

  logic clk;
  logic rst_n;
  logic eos;

  clk_rst_gen #(
    .ClkPeriod    (TbCyclTime),
    .RstClkCycles (5       )
  ) i_clk_rst_gen (
    .clk_o (clk  ),
    .rst_no(rst_n)
  );

  /*********
   *  AXI  *
   *********/

  // Master port

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH(TbAxiAddrWidth       ),
    .AXI_DATA_WIDTH(TbAxiSlvPortDataWidth),
    .AXI_ID_WIDTH  (TbAxiIdWidth         ),
    .AXI_USER_WIDTH(TbAxiUserWidth       )
  ) master_dv (
    .clk_i(clk)
  );

  AXI_BUS #(
    .AXI_ADDR_WIDTH(TbAxiAddrWidth       ),
    .AXI_DATA_WIDTH(TbAxiSlvPortDataWidth),
    .AXI_ID_WIDTH  (TbAxiIdWidth         ),
    .AXI_USER_WIDTH(TbAxiUserWidth       )
  ) master ();

  `AXI_ASSIGN(master, master_dv)

  typedef axi_test::axi_driver #(
    .AW            (TbAxiAddrWidth       ),
    .DW            (TbAxiSlvPortDataWidth),
    .IW            (TbAxiIdWidth         ),
    .UW            (TbAxiUserWidth       ),
    .TA            (TbApplTime           ),
    .TT            (TbTestTime           )
  ) master_drv_t;
  master_drv_t master_drv = new (master_dv);
  typedef master_drv_t::ax_beat_t mst_ax_beat_t;
  typedef master_drv_t::w_beat_t mst_w_beat_t;
  typedef master_drv_t::b_beat_t mst_b_beat_t;

  // Slave port

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH(TbAxiAddrWidth       ),
    .AXI_DATA_WIDTH(TbAxiMstPortDataWidth),
    .AXI_ID_WIDTH  (TbAxiIdWidth         ),
    .AXI_USER_WIDTH(TbAxiUserWidth       )
  ) slave_dv (
    .clk_i(clk)
  );

  AXI_BUS #(
    .AXI_ADDR_WIDTH(TbAxiAddrWidth       ),
    .AXI_DATA_WIDTH(TbAxiMstPortDataWidth),
    .AXI_ID_WIDTH  (TbAxiIdWidth         ),
    .AXI_USER_WIDTH(TbAxiUserWidth       )
  ) slave ();

  axi_test::axi_rand_slave #(
    .AW(TbAxiAddrWidth       ),
    .DW(TbAxiMstPortDataWidth),
    .IW(TbAxiIdWidth         ),
    .UW(TbAxiUserWidth       ),
    .TA(TbApplTime           ),
    .TT(TbTestTime           )
  ) slave_drv = new (slave_dv);

  `AXI_ASSIGN(slave_dv, slave)

  /*********
   *  DUT  *
   *********/

  axi_dw_converter_intf #(
    .AXI_MAX_READS          (4                    ),
    .AXI_ADDR_WIDTH         (TbAxiAddrWidth       ),
    .AXI_ID_WIDTH           (TbAxiIdWidth         ),
    .AXI_SLV_PORT_DATA_WIDTH(TbAxiSlvPortDataWidth),
    .AXI_MST_PORT_DATA_WIDTH(TbAxiMstPortDataWidth),
    .AXI_USER_WIDTH         (TbAxiUserWidth       )
  ) i_dw_converter (
    .clk_i (clk   ),
    .rst_ni(rst_n ),
    .slv   (master),
    .mst   (slave )
  );

  /*************
   *  DRIVERS  *
   *************/

  initial begin
    eos = 1'b0;

    // Configuration
    slave_drv.reset();
    master_drv.reset_master();

    // Wait for the reset before sending requests
    @(posedge rst_n);

    fork
      // Act as a sink
      slave_drv.run();
      begin
        automatic mst_ax_beat_t aw = new;
        automatic mst_w_beat_t w = new;
        automatic mst_b_beat_t b;
        aw.ax_addr = 64'h18;
        aw.ax_size = 3'd2;
        aw.ax_burst = axi_pkg::BURST_INCR;
        master_drv.send_aw(aw);
        w.w_data = 64'h07_06_05_04_03_02_01_00;
        w.w_strb = 8'b0000_1111;
        w.w_last = 1'b1;
        master_drv.send_w(w);
        master_drv.recv_b(b);
      end
    join_any

    // Done
    repeat (10) @(posedge clk);
    eos = 1'b1;
  end

  /*************
   *  MONITOR  *
   *************/

  initial begin : proc_monitor
    static tb_axi_dw_pkg::axi_dw_upsizer_monitor #(
      .AxiAddrWidth       (TbAxiAddrWidth       ),
      .AxiMstPortDataWidth(TbAxiMstPortDataWidth),
      .AxiSlvPortDataWidth(TbAxiSlvPortDataWidth),
      .AxiIdWidth         (TbAxiIdWidth         ),
      .AxiUserWidth       (TbAxiUserWidth       ),
      .TimeTest           (TbTestTime           )
    ) monitor = new (master_dv, slave_dv);
    fork
      monitor.run();
      forever begin
        #TbTestTime;
        if(eos) begin
          monitor.print_result();
          $stop()               ;
        end
        @(posedge clk);
      end
    join
  end

// vsim -voptargs=+acc work.tb_axi_dw_upsizer
endmodule
