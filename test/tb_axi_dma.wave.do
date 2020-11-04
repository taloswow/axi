onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_axi_dma/clk
add wave -noupdate /tb_axi_dma/rst_n
add wave -noupdate -expand -group Config -expand /tb_axi_dma/cfg_req
add wave -noupdate -expand -group Config -expand /tb_axi_dma/cfg_res
add wave -noupdate -expand -group AXI /tb_axi_dma/mem_req
add wave -noupdate -expand -group AXI /tb_axi_dma/mem_res
add wave -noupdate -expand -group CfgRegs /tb_axi_dma/i_axi_dma/i_axi_lite_regs/reg_d_i
add wave -noupdate -expand -group CfgRegs /tb_axi_dma/i_axi_dma/i_axi_lite_regs/reg_load_i
add wave -noupdate -expand -group CfgRegs /tb_axi_dma/i_axi_dma/i_axi_lite_regs/wr_active_o
add wave -noupdate -expand -group CfgRegs /tb_axi_dma/i_axi_dma/i_axi_lite_regs/rd_active_o
add wave -noupdate -expand -group CfgRegs /tb_axi_dma/i_axi_dma/i_axi_lite_regs/reg_q_o
add wave -noupdate -group Unions /tb_axi_dma/i_axi_dma/dma_conf_d
add wave -noupdate -group Unions -subitemconfig {/tb_axi_dma/i_axi_dma/dma_conf_q.dma -expand} /tb_axi_dma/i_axi_dma/dma_conf_q
add wave -noupdate -group {DMA backend ports} /tb_axi_dma/i_axi_dma/i_axi_dma_backend/axi_dma_res_i
add wave -noupdate -group {DMA backend ports} /tb_axi_dma/i_axi_dma/i_axi_dma_backend/axi_dma_req_o
add wave -noupdate -group {DMA backend ports} /tb_axi_dma/i_axi_dma/i_axi_dma_backend/burst_req_i
add wave -noupdate -group {DMA backend ports} /tb_axi_dma/i_axi_dma/i_axi_dma_backend/valid_i
add wave -noupdate -group {DMA backend ports} /tb_axi_dma/i_axi_dma/i_axi_dma_backend/ready_o
add wave -noupdate -group {DMA backend ports} /tb_axi_dma/i_axi_dma/i_axi_dma_backend/dma_id_i
add wave -noupdate -group {DMA backend ports} /tb_axi_dma/i_axi_dma/i_axi_dma_backend/backend_idle_o
add wave -noupdate -group {DMA backend ports} /tb_axi_dma/i_axi_dma/i_axi_dma_backend/trans_complete_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {9798817 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {7761437 ps} {21012556 ps}
