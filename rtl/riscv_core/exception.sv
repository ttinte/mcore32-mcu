import rv32_pkg::*;

module exception (
    input  logic        fetch_fault_i,
    input  logic        illegal_instr_i,
    input  logic        addr_misaligned_i,
    input  logic        data_misaligned_i,
    input  logic        load_fault_i,
    input  logic        store_fault_i,
    input  logic        is_load_i,
    input  logic [31:0] fetch_pc_i,
    input  logic [31:0] instr_pc_i,
    input  logic [31:0] instr_i,
    input  logic [31:0] branch_target_i,
    input  logic [31:0] data_addr_i,
    output exception_t  exc_o
);

    always_comb begin
        exc_o     = '0;
        exc_o.epc = instr_pc_i;

        if (fetch_fault_i) begin
            exc_o.valid = 1'b1;
            exc_o.cause = INSTR_ACCESS_FAULT;
            exc_o.epc   = fetch_pc_i;
            exc_o.tval  = fetch_pc_i;
        end
        else if (illegal_instr_i) begin
            exc_o.valid = 1'b1;
            exc_o.cause = ILLEGAL_INSTR;
            exc_o.tval  = instr_i;
        end
        else if (addr_misaligned_i) begin
            exc_o.valid = 1'b1;
            exc_o.cause = INSTR_ADDR_MISALIGNED;
            exc_o.tval  = branch_target_i;
        end
        else if (data_misaligned_i) begin
            exc_o.valid = 1'b1;
            exc_o.cause = is_load_i ? LOAD_ADDR_MISALIGNED :
                                      STORE_ADDR_MISALIGNED;
            exc_o.tval  = data_addr_i;
        end
        else if (load_fault_i || store_fault_i) begin
            exc_o.valid = 1'b1;
            exc_o.cause = load_fault_i ? LOAD_ACCESS_FAULT:
                                         STORE_ACCESS_FAULT;
            exc_o.tval  = data_addr_i;
        end
    end

endmodule
