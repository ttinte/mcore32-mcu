package rv32_pkg;

    typedef enum logic [6:0] {
        OPCODE_OP     = 7'h33,
        OPCODE_OP_IMM = 7'h13,
        OPCODE_LOAD   = 7'h03,
        OPCODE_STORE  = 7'h23,
        OPCODE_BRANCH = 7'h63,
        OPCODE_AUIPC  = 7'h17,
        OPCODE_LUI    = 7'h37,
        OPCODE_JALR   = 7'h67,
        OPCODE_JAL    = 7'h6F
    } opcode_e;

    typedef enum logic {
        MEM_ADDR_PC,
        MEM_ADDR_RESULT
    } mem_addr_sel_e;

    typedef enum logic [2:0] {
        LOAD_BYTE  = 3'b000,
        LOAD_HALF  = 3'b001,
        LOAD_WORD  = 3'b010,
        LOAD_BYTEU = 3'b100,
        LOAD_HALFU = 3'b101,
        LOAD_NONE  = 3'b111
    } load_op_e;

    typedef enum logic [2:0] {
        STORE_BYTE = 3'b000,
        STORE_HALF = 3'b001,
        STORE_WORD = 3'b010,
        STORE_NONE = 3'b111
    } store_op_e;

    typedef enum logic [2:0] {
        IMM_NONE,
        IMM_I,
        IMM_S,
        IMM_B,
        IMM_U,
        IMM_J
    } imm_sel_e;

    typedef enum logic [1:0] {
        OP_A_PC,
        OP_A_OLD_PC,
        OP_A_RS1
    } op_a_sel_e;

    typedef enum logic [1:0] {
        OP_B_FOUR,
        OP_B_RS2,
        OP_B_IMM
    } op_b_sel_e;

    typedef enum logic [3:0] {
        ALU_ADD    = 4'b0_000,
        ALU_SUB    = 4'b1_000,
        ALU_SLL    = 4'b0_001,
        ALU_SLT    = 4'b0_010,
        ALU_SLTU   = 4'b0_011,
        ALU_XOR    = 4'b0_100,
        ALU_SRL    = 4'b0_101,
        ALU_SRA    = 4'b1_101,
        ALU_OR     = 4'b0_110,
        ALU_AND    = 4'b0_111,
        ALU_PASS_B = 4'b1_001
    } alu_op_e;

    typedef struct packed {
        logic zero;
        logic sign;
        logic carry;
        logic overflow;
    } alu_flags_t;

    typedef enum logic {
        RESULT_ALU_OUT_Q,
        RESULT_LOAD_DATA_Q
    } result_sel_e;

    typedef struct packed {
        logic           pc_we;
        logic           pc_clear_lsb;
        mem_addr_sel_e  mem_addr_sel;
        logic           mem_we;
        load_op_e       load_op;
        store_op_e      store_op;
        logic           ir_we;
        logic           reg_we;
        imm_sel_e       imm_sel;
        op_a_sel_e      op_a_sel;
        op_b_sel_e      op_b_sel;
        alu_op_e        alu_op;
        logic           alu_out_we;
        result_sel_e    result_sel;
    } decode_ctrl_t;

endpackage
