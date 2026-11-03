import soc_addr_map_pkg::*;

module soc_top #(
    parameter int unsigned MEM_DEPTH  = RAM_DEPTH_WORDS,
    parameter string       INIT_FILE  = "",
    parameter int unsigned CLOCK_RATE = 70_000_000,
    parameter int unsigned BAUD_RATE  = 115_200,
    parameter int unsigned FIFO_DEPTH = 32
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic rxd_i,
    output logic txd_o
);

    initial begin : check_soc
        if ((apb_pkg::APB_ADDR_WIDTH != 32) ||
            (apb_pkg::APB_DATA_WIDTH != 32))
            $fatal(1, "SoC requires 32-bit APB");

        if (RAM_BASE_ADDR != 0)
            $fatal(1, "SoC requires RAM_BASE_ADDR = 0");

        if ((RAM_END_ADDR <= RAM_BASE_ADDR) ||
            (RAM_BASE_ADDR[1:0] != 0) ||
            (RAM_END_ADDR[1:0] != 0))
            $fatal(1, "Invalid or unaligned RAM address range");

        if (APB_BASE_ADDR >= APB_END_ADDR)
            $fatal(1, "Invalid APB window");

        for (int i = 0; i < apb_addr_map_pkg::NUM_SLAVES; i++) begin
            if ((64'(apb_addr_map_pkg::PERIPH_BASE_ADDR[i]) < 64'(APB_BASE_ADDR)) ||
                ((64'(apb_addr_map_pkg::PERIPH_BASE_ADDR[i]) +
                (64'd1 << apb_addr_map_pkg::SLOT_OFFSET_WIDTH)) > 64'(APB_END_ADDR)))
                $fatal(1, "Slave %0d is outside APB window", i);
        end
    end

    logic        bus_valid;
    logic        bus_ready;
    logic        bus_error;
    logic [31:0] bus_addr;
    logic        bus_we;
    logic [31:0] bus_wdata;
    logic [3:0]  bus_wstrb;
    logic [31:0] bus_rdata;

    logic        ram_valid;
    logic        ram_ready;
    logic        ram_write;
    logic [31:0] ram_rdata;

    logic        apb_valid;
    logic        apb_ready;
    logic        apb_error;
    logic        apb_write;
    logic [31:0] apb_rdata;

    rv32_core u_rv32_core (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .mem_valid_o        (bus_valid),
        .mem_ready_i        (bus_ready),
        .mem_error_i        (bus_error),
        .mem_addr_o         (bus_addr),
        .mem_we_o           (bus_we),
        .mem_wdata_o        (bus_wdata),
        .mem_wstrb_o        (bus_wstrb),
        .mem_rdata_i        (bus_rdata),
        .trap_o             (),
        .trace_valid_o      (),
        .trace_pc_o         (),
        .trace_instr_o      (),
        .trace_rf_we_o      (),
        .trace_rf_rd_o      (),
        .trace_rf_wdata_o   ()
    );

    addr_decoder #(
        .DEPTH_WORDS        (MEM_DEPTH)
    ) u_addr_decoder (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .valid_i            (bus_valid),
        .ready_o            (bus_ready),
        .error_o            (bus_error),
        .addr_i             (bus_addr),
        .we_i               (bus_we),
        .rdata_o            (bus_rdata),
        .ram_valid_o        (ram_valid),
        .ram_ready_i        (ram_ready),
        .ram_write_o        (ram_write),
        .ram_rdata_i        (ram_rdata),
        .apb_valid_o        (apb_valid),
        .apb_ready_i        (apb_ready),
        .apb_error_i        (apb_error),
        .apb_write_o        (apb_write),
        .apb_rdata_i        (apb_rdata)
    );

    ram #(
        .DEPTH_WORDS        (MEM_DEPTH),
        .INIT_FILE          (INIT_FILE)
    ) u_ram (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .valid_i            (ram_valid),
        .ready_o            (ram_ready),
        .addr_i             (bus_addr),
        .write_i            (ram_write),
        .wdata_i            (bus_wdata),
        .wstrb_i            (bus_wstrb),
        .rdata_o            (ram_rdata)
    );

    apb_subsystem #(
        .CLOCK_RATE         (CLOCK_RATE),
        .BAUD_RATE          (BAUD_RATE),
        .FIFO_DEPTH         (FIFO_DEPTH)
    ) u_apb_subsystem (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .req_valid_i        (apb_valid),
        .rsp_ready_o        (apb_ready),
        .rsp_error_o        (apb_error),
        .addr_i             (bus_addr),
        .write_i            (apb_write),
        .wdata_i            (bus_wdata),
        .wstrb_i            (bus_wstrb),
        .rdata_o            (apb_rdata),
        .rxd_i              (rxd_i),
        .txd_o              (txd_o)
    );

endmodule
