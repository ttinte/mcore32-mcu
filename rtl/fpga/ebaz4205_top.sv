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

    input  logic        uart_rx_pin_i,
    output logic        uart_tx_pin_o,

    input  logic        pir_i,
    inout  wire         i2c_scl_io,
    inout  wire         i2c_sda_io,

    input  logic [4:0]  key_n_i,
    output logic        buzzer_o,

    output logic [2:0]  carrier_led_o,

    output logic        led_green_no,
    output logic        led_red_no
);

    logic        pl_clk;
    logic        ps_pl_rst_n;
    logic        soc_rst_n;

    localparam int unsigned GPIO_WIDTH = 32;
    localparam int unsigned GPIO_BUZZER_GATE_BIT = 11;
    localparam int unsigned GPIO_CARRIER_LED_BIT = 8;
    localparam int unsigned BUZZER_HALF_CYCLES = CLOCK_RATE / 4000;
    localparam int unsigned BUZZER_COUNT_WIDTH =
        BUZZER_HALF_CYCLES > 1 ? $clog2(BUZZER_HALF_CYCLES) : 1;

    logic [GPIO_WIDTH-1:0] gpio_i;
    logic [GPIO_WIDTH-1:0] gpio_o;
    logic [GPIO_WIDTH-1:0] gpio_oe;
    logic [25:0]           pl_heartbeat_q;
    rv32_pkg::exception_t  cpu_trap;
    logic                  trap_seen_q;
    logic                  scl_drive_low;
    logic                  sda_drive_low;
    logic [BUZZER_COUNT_WIDTH-1:0] buzzer_count_q;
    logic                  buzzer_tone_q;

    initial begin
        if (BUZZER_HALF_CYCLES == 0)
            $fatal(1, "CLOCK_RATE must be at least 4000 Hz for the buzzer");
    end

    assign gpio_i = {{(GPIO_WIDTH-6){1'b0}}, pir_i, key_n_i};
    assign i2c_scl_io = scl_drive_low ? 1'b0 : 1'bz;
    assign i2c_sda_io = sda_drive_low ? 1'b0 : 1'bz;

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
        .pl_rst_n           (ps_pl_rst_n)
    );

    assign soc_rst_n = ps_pl_rst_n;

    soc_top #(
        .MEM_DEPTH          (MEM_DEPTH),
        .INIT_FILE          (INIT_FILE),
        .CLOCK_RATE         (CLOCK_RATE),
        .BAUD_RATE          (BAUD_RATE),
        .FIFO_DEPTH         (FIFO_DEPTH),
        .GPIO_WIDTH         (GPIO_WIDTH)
    ) u_soc_top (
        .clk_i              (pl_clk),
        .rst_ni             (soc_rst_n),
        .rxd_i              (uart_rx_pin_i),
        .txd_o              (uart_tx_pin_o),
        .scl_i              (i2c_scl_io),
        .sda_i              (i2c_sda_io),
        .scl_drive_low_o    (scl_drive_low),
        .sda_drive_low_o    (sda_drive_low),
        .gpio_i             (gpio_i),
        .gpio_o             (gpio_o),
        .gpio_oe_o          (gpio_oe),
        .cpu_trap_o         (cpu_trap)
    );

    always_ff @(posedge pl_clk or negedge soc_rst_n) begin
        if (!soc_rst_n) begin
            pl_heartbeat_q <= '0;
        end else begin
            pl_heartbeat_q <= pl_heartbeat_q + 1'b1;
        end
    end

    always_ff @(posedge pl_clk or negedge soc_rst_n) begin
        if (!soc_rst_n) trap_seen_q <= 1'b0;
        else if (cpu_trap.valid) trap_seen_q <= 1'b1;
    end

    assign led_green_no = ~pl_heartbeat_q[25];
    assign led_red_no   = soc_rst_n && (&key_n_i) && !trap_seen_q;

    always_ff @(posedge pl_clk or negedge soc_rst_n) begin
        if (!soc_rst_n) begin
            buzzer_count_q <= '0;
            buzzer_tone_q <= 1'b0;
        end else if (!gpio_oe[GPIO_BUZZER_GATE_BIT] ||
                     !gpio_o[GPIO_BUZZER_GATE_BIT]) begin
            buzzer_count_q <= '0;
            buzzer_tone_q <= 1'b0;
        end else if (buzzer_count_q == BUZZER_COUNT_WIDTH'(BUZZER_HALF_CYCLES - 1)) begin
            buzzer_count_q <= '0;
            buzzer_tone_q <= ~buzzer_tone_q;
        end else begin
            buzzer_count_q <= buzzer_count_q + 1'b1;
        end
    end

    assign buzzer_o = gpio_oe[GPIO_BUZZER_GATE_BIT] &&
                      gpio_o[GPIO_BUZZER_GATE_BIT] && buzzer_tone_q;
    assign carrier_led_o = gpio_o[GPIO_CARRIER_LED_BIT +: 3] &
                           gpio_oe[GPIO_CARRIER_LED_BIT +: 3];

endmodule
