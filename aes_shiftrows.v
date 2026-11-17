module aes_shiftrows(state, state_out);
    input [127:0] state;
    output [127:0] state_out;

    //--------------------
    // S(0,0) state[127:120]
    // S(0,1) state[95:88]
    // S(0,2) state[63:56]
    // S(0,3) state[31:24]
    //--------------------
    // S(1,0) state[119:112]
    // S(1,1) state[87:80]
    // S(1,2) state[55:48]
    // S(1,3) state[23:16]
    //--------------------
    // S(2,0) state[111:104]
    // S(2,1) state[79:72]
    // S(2,2) state[47:40]
    // S(2,3) state[15:8]
    //--------------------
    // S(3,0) state[103:96]
    // S(3,1) state[71:64]
    // S(3,2) state[39:32]
    // S(3,3) state[7:0]
    //--------------------

    // 1st row no shift
    assign state_out[127:120] = state[127:120];
    assign state_out[95:88] = state[95:88];
    assign state_out[63:56] = state[63:56];
    assign state_out[31:24] = state[31:24];

    // 2nd row shift 1
    assign state_out[119:112] = state[87:80];
    assign state_out[87:80] = state[55:48];
    assign state_out[55:48] = state[23:16];
    assign state_out[23:16] = state[119:112];

    // 3rd row shift 2
    assign state_out[111:104] = state[47:40];
    assign state_out[79:72] = state[15:8];
    assign state_out[47:40] = state[111:104];
    assign state_out[15:8] = state[79:72];

    // 4th row shift 3
    assign state_out[103:96] = state[7:0];
    assign state_out[71:64] = state[103:96];
    assign state_out[39:32] = state[71:64];
    assign state_out[7:0] = state[39:32];
endmodule

