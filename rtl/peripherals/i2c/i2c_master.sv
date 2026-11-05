//-----------------------------------------------------------------------------
//  Module   : i2c_master
//  Children : None
//
//  Description:
//     Bus-independent, single-master I2C controller for one-byte transfers
//     with 7-bit addressing. Each start_i request sends an address byte and
//     then either writes tx_data_i or reads one byte into rx_data_o.
//
//     scl_drive_low_o and sda_drive_low_o are open-drain controls: drive the
//     pin low when asserted and otherwise release it through an I/O buffer.
//     The controller supports slave clock stretching and detects arbitration
//     loss while transmitting a released (logic-one) SDA bit.
//-----------------------------------------------------------------------------

module i2c_master #(
    parameter int unsigned CLOCK_RATE = 50_000_000,
    parameter int unsigned I2C_RATE   = 100_000
) (
    input  logic       clk_i,
    input  logic       rst_ni,

    input  logic       start_i,
    input  logic       read_i,
    input  logic [6:0] address_i,
    input  logic [7:0] tx_data_i,

    output logic [7:0] rx_data_o,
    output logic       busy_o,
    output logic       done_o,
    output logic       ack_error_o,
    output logic       arbitration_lost_o,

    input  logic       scl_i,
    input  logic       sda_i,
    output logic       scl_drive_low_o,
    output logic       sda_drive_low_o
);

    localparam int unsigned HALF_PERIOD_CYCLES =
        (CLOCK_RATE + I2C_RATE) / (2 * I2C_RATE);
    localparam int unsigned DIV_WIDTH =
        (HALF_PERIOD_CYCLES > 1) ? $clog2(HALF_PERIOD_CYCLES) : 1;

    initial begin : check_i2c_master
        if (CLOCK_RATE == 0)
            $fatal(1, "CLOCK_RATE must be greater than zero");
        if (I2C_RATE == 0)
            $fatal(1, "I2C_RATE must be greater than zero");
        if (CLOCK_RATE < 2 * I2C_RATE)
            $fatal(1, "CLOCK_RATE must be at least twice I2C_RATE");
    end

    typedef enum logic [3:0] {
        IDLE,
        BUS_WAIT,
        START_HOLD,
        TX_LOW,
        TX_HIGH,
        ACK_LOW,
        ACK_HIGH,
        RX_LOW,
        RX_HIGH,
        NACK_LOW,
        NACK_HIGH,
        STOP_LOW,
        STOP_HIGH,
        STOP_RELEASE
    } state_e;

    state_e state_q;

    logic [DIV_WIDTH-1:0] divider_q;
    logic                 half_period_tick;
    logic                 waiting_for_scl_high;
    logic                 sda_drive_low_next;
    logic [1:0]           scl_sync_q;
    logic [1:0]           sda_sync_q;
    logic                 scl;
    logic                 sda;

    logic                 read_q;
    logic                 data_phase_q;
    logic [7:0]           tx_data_q;
    logic [7:0]           tx_shift_q;
    logic [7:0]           rx_shift_q;
    logic [2:0]           bit_index_q;

    assign busy_o           = (state_q != IDLE);
    assign half_period_tick =
        (divider_q == DIV_WIDTH'(HALF_PERIOD_CYCLES - 1));
    assign scl = scl_sync_q[1];
    assign sda = sda_sync_q[1];
    assign waiting_for_scl_high = (state_q == TX_HIGH) ||
                                  (state_q == ACK_HIGH) ||
                                  (state_q == RX_HIGH) ||
                                  (state_q == NACK_HIGH) ||
                                  (state_q == STOP_HIGH);

    // Synchronize the sampled bus levels into the controller clock domain.
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            scl_sync_q <= 2'b11;
            sda_sync_q <= 2'b11;
        end
        else begin
            scl_sync_q <= {scl_sync_q[0], scl_i};
            sda_sync_q <= {sda_sync_q[0], sda_i};
        end
    end

    // Half-period enable used by all bus phases. While idle the divider is
    // held at zero so every accepted request begins with a complete phase.
    // Count a HIGH phase only after the sampled pin is actually high. A slow
    // pull-up or clock stretching must not shorten the visible HIGH pulse.
    always_ff @(posedge clk_i) begin
        if (!rst_ni || (state_q == IDLE) || (waiting_for_scl_high && !scl)) begin
            divider_q <= '0;
        end
        else if (half_period_tick) begin
            divider_q <= '0;
        end
        else begin
            divider_q <= divider_q + 1'b1;
        end
    end

    // Hold the previous data/ACK value across the falling edge of SCL.
    // Updating both outputs on the same FPGA edge allows a faster SDA path
    // to change while SCL is still physically high (false START/STOP).
    // The synchronized low level confirms the fall before SDA is updated.
    always_ff @(posedge clk_i) begin
        if (!rst_ni)
            sda_drive_low_o <= 1'b0;
        else if (!(scl_drive_low_o && scl))
            sda_drive_low_o <= sda_drive_low_next;
    end

    // Open-drain requests for each transfer phase. START/STOP intentionally
    // change SDA while SCL is high; data and ACK changes wait for SCL low.
    always_comb begin
        scl_drive_low_o = 1'b0;
        sda_drive_low_next = 1'b0;

        unique case (state_q)
            START_HOLD: begin
                sda_drive_low_next = 1'b1;
            end

            TX_LOW: begin
                scl_drive_low_o = 1'b1;
                sda_drive_low_next = ~tx_shift_q[bit_index_q];
            end

            TX_HIGH: begin
                sda_drive_low_next = ~tx_shift_q[bit_index_q];
            end

            ACK_LOW,
            RX_LOW,
            NACK_LOW: begin
                scl_drive_low_o = 1'b1;
            end

            STOP_LOW: begin
                scl_drive_low_o = 1'b1;
                sda_drive_low_next = 1'b1;
            end

            STOP_HIGH: begin
                sda_drive_low_next = 1'b1;
            end

            default: ;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            state_q            <= IDLE;
            read_q             <= 1'b0;
            data_phase_q       <= 1'b0;
            tx_data_q          <= '0;
            tx_shift_q         <= '0;
            rx_shift_q         <= '0;
            rx_data_o          <= '0;
            bit_index_q        <= '0;
            done_o             <= 1'b0;
            ack_error_o        <= 1'b0;
            arbitration_lost_o <= 1'b0;
        end
        else begin
            done_o <= 1'b0;

            unique case (state_q)
                IDLE: begin
                    if (start_i) begin
                        read_q             <= read_i;
                        data_phase_q       <= 1'b0;
                        tx_data_q          <= tx_data_i;
                        tx_shift_q         <= {address_i, read_i};
                        rx_shift_q         <= '0;
                        bit_index_q        <= 3'd7;
                        ack_error_o        <= 1'b0;
                        arbitration_lost_o <= 1'b0;
                        state_q            <= BUS_WAIT;
                    end
                end

                BUS_WAIT: begin
                    if (half_period_tick && scl && sda)
                        state_q <= START_HOLD;
                end

                START_HOLD: begin
                    if (half_period_tick)
                        state_q <= TX_LOW;
                end

                TX_LOW: begin
                    if (half_period_tick)
                        state_q <= TX_HIGH;
                end

                TX_HIGH: begin
                    if (half_period_tick && scl) begin
                        if (tx_shift_q[bit_index_q] && !sda) begin
                            arbitration_lost_o <= 1'b1;
                            done_o             <= 1'b1;
                            state_q            <= IDLE;
                        end
                        else if (bit_index_q == 0) begin
                            state_q <= ACK_LOW;
                        end
                        else begin
                            bit_index_q <= bit_index_q - 3'd1;
                            state_q     <= TX_LOW;
                        end
                    end
                end

                ACK_LOW: begin
                    if (half_period_tick)
                        state_q <= ACK_HIGH;
                end

                ACK_HIGH: begin
                    if (half_period_tick && scl) begin
                        if (sda) begin
                            ack_error_o <= 1'b1;
                            state_q     <= STOP_LOW;
                        end
                        else if (!data_phase_q && read_q) begin
                            rx_shift_q  <= '0;
                            bit_index_q <= 3'd7;
                            state_q     <= RX_LOW;
                        end
                        else if (!data_phase_q) begin
                            data_phase_q <= 1'b1;
                            tx_shift_q   <= tx_data_q;
                            bit_index_q  <= 3'd7;
                            state_q      <= TX_LOW;
                        end
                        else begin
                            state_q <= STOP_LOW;
                        end
                    end
                end

                RX_LOW: begin
                    if (half_period_tick)
                        state_q <= RX_HIGH;
                end

                RX_HIGH: begin
                    if (half_period_tick && scl) begin
                        rx_shift_q[bit_index_q] <= sda;

                        if (bit_index_q == 0) begin
                            rx_data_o <= {rx_shift_q[7:1], sda};
                            state_q   <= NACK_LOW;
                        end
                        else begin
                            bit_index_q <= bit_index_q - 3'd1;
                            state_q     <= RX_LOW;
                        end
                    end
                end

                NACK_LOW: begin
                    if (half_period_tick)
                        state_q <= NACK_HIGH;
                end

                NACK_HIGH: begin
                    if (half_period_tick && scl)
                        state_q <= STOP_LOW;
                end

                STOP_LOW: begin
                    if (half_period_tick)
                        state_q <= STOP_HIGH;
                end

                STOP_HIGH: begin
                    if (half_period_tick && scl)
                        state_q <= STOP_RELEASE;
                end

                STOP_RELEASE: begin
                    if (half_period_tick) begin
                        done_o  <= 1'b1;
                        state_q <= IDLE;
                    end
                end

                default: state_q <= IDLE;
            endcase
        end
    end

endmodule
