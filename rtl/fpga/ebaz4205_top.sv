module ebaz4205_top #(
    parameter int unsigned MEM_DEPTH  = soc_addr_map_pkg::RAM_DEPTH_WORDS,
    parameter string       INIT_FILE  = "firmware.mem",
    parameter int unsigned CLOCK_RATE = 70_000_000,
    parameter int unsigned BAUD_RATE  = 115_200,
    parameter int unsigned FIFO_DEPTH = 32
) (
    inout  wire [14:0] DDR_addr,
    inout  wire [2:0]  DDR_ba,
    inout  wire        DDR_cas_n,
    inout  wire        DDR_ck_n,
    inout  wire        DDR_ck_p,
    inout  wire        DDR_cke,
    inout  wire        DDR_cs_n,
    inout  wire [3:0]  DDR_dm,
    inout  wire [31:0] DDR_dq,
    inout  wire [3:0]  DDR_dqs_n,
    inout  wire [3:0]  DDR_dqs_p,
    inout  wire        DDR_odt,
    inout  wire        DDR_ras_n,
    inout  wire        DDR_reset_n,
    inout  wire        DDR_we_n,
    inout  wire        FIXED_IO_ddr_vrn,
    inout  wire        FIXED_IO_ddr_vrp,
    inout  wire [53:0] FIXED_IO_mio,
    inout  wire        FIXED_IO_ps_clk,
    inout  wire        FIXED_IO_ps_porb,
    inout  wire        FIXED_IO_ps_srstb,

    input  logic       uart_rx_pin_i,
    output logic       uart_tx_pin_o,

    output logic       led_green_no,
    output logic       led_red_no
);

    logic pl_clk, soc_rst_n;
    logic [25:0] heartbeat_q;

    ps7_fclk_wrapper u_ps7_fclk_wrapper (
        .DDR_addr           (DDR_addr),
        .DDR_ba             (DDR_ba),
        .DDR_cas_n          (DDR_cas_n),
        .DDR_ck_n           (DDR_ck_n),
        .DDR_ck_p           (DDR_ck_p),
        .DDR_cke            (DDR_cke),
        .DDR_cs_n           (DDR_cs_n),
        .DDR_dm             (DDR_dm),
        .DDR_dq             (DDR_dq),
        .DDR_dqs_n          (DDR_dqs_n),
        .DDR_dqs_p          (DDR_dqs_p),
        .DDR_odt            (DDR_odt),
        .DDR_ras_n          (DDR_ras_n),
        .DDR_reset_n        (DDR_reset_n),
        .DDR_we_n           (DDR_we_n),
        .FIXED_IO_ddr_vrn   (FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp   (FIXED_IO_ddr_vrp),
        .FIXED_IO_mio       (FIXED_IO_mio),
        .FIXED_IO_ps_clk    (FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb   (FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb  (FIXED_IO_ps_srstb),
        .pl_clk             (pl_clk),
        .pl_rst_n           (soc_rst_n)
    );

    soc_top #(
        .MEM_DEPTH          (MEM_DEPTH),
        .INIT_FILE          (INIT_FILE),
        .CLOCK_RATE         (CLOCK_RATE),
        .BAUD_RATE          (BAUD_RATE),
        .FIFO_DEPTH         (FIFO_DEPTH)
    ) u_soc_top (
        .clk_i              (pl_clk),
        .rst_ni             (soc_rst_n),
        .rxd_i              (uart_rx_pin_i),
        .txd_o              (uart_tx_pin_o)
    );

    always_ff @(posedge pl_clk or negedge soc_rst_n) begin
        if (!soc_rst_n) heartbeat_q <= '0;
        else heartbeat_q <= heartbeat_q + 1'b1;
    end

    // Active-low LEDs: green heartbeat; red on while PL reset is asserted.
    assign led_green_no = ~heartbeat_q[25];
    assign led_red_no = soc_rst_n;

endmodule
