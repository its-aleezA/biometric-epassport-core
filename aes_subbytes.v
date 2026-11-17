module aes_subbytes(
    input  wire [127:0] state,
    output wire [127:0] state_out
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : SBOXES
            aes_sbox sbox_inst (
                .state    (state[127 - 8*i -: 8]),
                .stateOut (state_out[127 - 8*i -: 8])
            );
        end
    endgenerate
endmodule
