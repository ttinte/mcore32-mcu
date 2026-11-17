//-----------------------------------------------------------------------------
//  Module   : dht22_master
//
//  Description:
//     Single-wire DHT22/AM2302 transaction engine.  A request holds the
//     open-drain data line low for START_LOW_US, releases it, receives the
//     sensor response, then captures its 40-bit frame.  Timing is measured
//     with a one-microsecond tick derived from CLOCK_RATE.
//
//     The engine reports the decoded humidity (0.1 %RH) and signed
//     temperature (0.1 degC).  Data is valid only when the frame checksum
//     matches.  Sampling interval policy belongs to firmware.
//-----------------------------------------------------------------------------

module dht22_master #(
    parameter int unsigned CLOCK_RATE  = 70_000_000,
    parameter int unsigned START_LOW_US = 1_100,
    parameter int unsigned TIMEOUT_US   = 200,
    parameter int unsigned ONE_MIN_US   = 50
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        start_i,

    input  logic        dht_i,
    output logic        dht_drive_low_o,

    output logic        busy_o,
    output logic        done_o,
    output logic        checksum_error_o,
    output logic        timeout_o,
    output logic [15:0] humidity_o,
    output logic signed [15:0] temperature_o
);

    localparam int unsigned US_DIVISOR = CLOCK_RATE / 1_000_000;
    localparam int unsigned US_DIV_WIDTH =
        US_DIVISOR > 1 ? $clog2(US_DIVISOR) : 1;

    typedef enum logic [3:0] {
        IDLE,
        START_LOW,
        RELEASE_SETTLE,
        WAIT_RESPONSE_LOW,
        WAIT_RESPONSE_HIGH,
        WAIT_RESPONSE_END,
        WAIT_BIT_HIGH,
        MEASURE_BIT_HIGH,
        COMPLETE
    } state_e;

    state_e state_q;
    logic [US_DIV_WIDTH-1:0] us_divider_q;
    logic                    us_tick;
    logic [15:0]             phase_us_q;
    logic [5:0]              bit_count_q;
    logic [39:0]             frame_q;
    logic                    bit_low_seen_q;
    logic                    release_seen_high_q;
    logic [1:0]              dht_sync_q;
    logic                    dht;

    initial begin : check_dht22_master
        if (CLOCK_RATE < 1_000_000 || (CLOCK_RATE % 1_000_000) != 0)
            $fatal(1, "CLOCK_RATE must be an integer number of MHz");
        if (START_LOW_US < 1 || TIMEOUT_US < 1)
            $fatal(1, "DHT22 timing parameters must be non-zero");
    end

    assign us_tick = us_divider_q == US_DIV_WIDTH'(US_DIVISOR - 1);
    assign dht = dht_sync_q[1];
    assign busy_o = state_q != IDLE;
    assign dht_drive_low_o = state_q == START_LOW;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            us_divider_q <= '0;
            dht_sync_q <= 2'b11;
        end else begin
            dht_sync_q <= {dht_sync_q[0], dht_i};
            if (state_q == IDLE || us_tick)
                us_divider_q <= '0;
            else
                us_divider_q <= us_divider_q + 1'b1;
        end
    end

    always_ff @(posedge clk_i) begin
        logic [39:0] completed_frame;
        logic [15:0] raw_temperature;
        logic [7:0] checksum;

        if (!rst_ni) begin
            state_q            <= IDLE;
            phase_us_q         <= '0;
            bit_count_q        <= '0;
            frame_q            <= '0;
            bit_low_seen_q     <= 1'b0;
            release_seen_high_q <= 1'b0;
            done_o             <= 1'b0;
            checksum_error_o   <= 1'b0;
            timeout_o          <= 1'b0;
            humidity_o         <= '0;
            temperature_o      <= '0;
        end else begin
            done_o <= 1'b0;

            unique case (state_q)
                IDLE: if (start_i) begin
                    phase_us_q       <= '0;
                    bit_count_q      <= '0;
                    frame_q          <= '0;
                    bit_low_seen_q   <= 1'b0;
                    release_seen_high_q <= 1'b0;
                    checksum_error_o <= 1'b0;
                    timeout_o        <= 1'b0;
                    state_q          <= START_LOW;
                end

                START_LOW: if (us_tick) begin
                    if (phase_us_q + 16'd1 >= START_LOW_US) begin
                        phase_us_q <= '0;
                        state_q <= RELEASE_SETTLE;
                    end else begin
                        phase_us_q <= phase_us_q + 1'b1;
                    end
                end

                /* The input synchronizer still sees the master's own LOW
                 * for two cycles after release.  Observe a released HIGH
                 * first, otherwise that stale level would look like the
                 * sensor's response pulse. */
                RELEASE_SETTLE: if (us_tick) begin
                    if (dht) release_seen_high_q <= 1'b1;
                    if (release_seen_high_q) begin
                        phase_us_q <= '0;
                        state_q <= WAIT_RESPONSE_LOW;
                    end else if (phase_us_q + 16'd1 >= TIMEOUT_US) begin
                        timeout_o <= 1'b1;
                        state_q <= COMPLETE;
                    end else begin
                        phase_us_q <= phase_us_q + 1'b1;
                    end
                end

                WAIT_RESPONSE_LOW: if (us_tick) begin
                    if (!dht) begin
                        phase_us_q <= '0;
                        state_q <= WAIT_RESPONSE_HIGH;
                    end else if (phase_us_q + 16'd1 >= TIMEOUT_US) begin
                        timeout_o <= 1'b1;
                        state_q <= COMPLETE;
                    end else begin
                        phase_us_q <= phase_us_q + 1'b1;
                    end
                end

                WAIT_RESPONSE_HIGH: if (us_tick) begin
                    if (dht) begin
                        phase_us_q <= '0;
                        state_q <= WAIT_RESPONSE_END;
                    end else if (phase_us_q + 16'd1 >= TIMEOUT_US) begin
                        timeout_o <= 1'b1;
                        state_q <= COMPLETE;
                    end else begin
                        phase_us_q <= phase_us_q + 1'b1;
                    end
                end

                WAIT_RESPONSE_END: if (us_tick) begin
                    if (!dht) begin
                        phase_us_q <= '0;
                        bit_low_seen_q <= 1'b0;
                        state_q <= WAIT_BIT_HIGH;
                    end else if (phase_us_q + 16'd1 >= TIMEOUT_US) begin
                        timeout_o <= 1'b1;
                        state_q <= COMPLETE;
                    end else begin
                        phase_us_q <= phase_us_q + 1'b1;
                    end
                end

                WAIT_BIT_HIGH: if (us_tick) begin
                    if (!dht) begin
                        /* Require one sampled low period before accepting a
                         * data-high phase.  This separates the final sensor
                         * response pulse from the first data bit. */
                        bit_low_seen_q <= 1'b1;
                        phase_us_q <= '0;
                    end else if (bit_low_seen_q) begin
                        phase_us_q <= '0;
                        state_q <= MEASURE_BIT_HIGH;
                    end else if (phase_us_q + 16'd1 >= TIMEOUT_US) begin
                        timeout_o <= 1'b1;
                        state_q <= COMPLETE;
                    end else begin
                        phase_us_q <= phase_us_q + 1'b1;
                    end
                end

                MEASURE_BIT_HIGH: if (us_tick) begin
                    if (!dht) begin
                        completed_frame = {frame_q[38:0], phase_us_q >= ONE_MIN_US};
                        frame_q <= completed_frame;
                        if (bit_count_q == 6'd39) begin
                            checksum = completed_frame[39:32] + completed_frame[31:24] +
                                       completed_frame[23:16] + completed_frame[15:8];
                            if (checksum == completed_frame[7:0]) begin
                                humidity_o <= completed_frame[39:24];
                                raw_temperature = completed_frame[23:8];
                                if (raw_temperature[15])
                                    temperature_o <= -$signed({1'b0, raw_temperature[14:0]});
                                else
                                    temperature_o <= $signed(raw_temperature);
                            end else begin
                                checksum_error_o <= 1'b1;
                            end
                            state_q <= COMPLETE;
                        end else begin
                            bit_count_q <= bit_count_q + 1'b1;
                            bit_low_seen_q <= 1'b0;
                            phase_us_q <= '0;
                            state_q <= WAIT_BIT_HIGH;
                        end
                    end else if (phase_us_q + 16'd1 >= TIMEOUT_US) begin
                        timeout_o <= 1'b1;
                        state_q <= COMPLETE;
                    end else begin
                        phase_us_q <= phase_us_q + 1'b1;
                    end
                end

                COMPLETE: begin
                    done_o <= 1'b1;
                    state_q <= IDLE;
                end

                default: state_q <= IDLE;
            endcase
        end
    end

endmodule
