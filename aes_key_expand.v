// ============================================================================
// KeyExpansionRound.v
// Single Round of AES Key Expansion
// This is extracted from the original KeyExpansion.v
// ============================================================================

module aes_key_expand_round #(parameter Nk = 4, parameter Nr = 10) (round_count, key_in, key_out);
    input [3:0] round_count;
    input [32 * Nk - 1:0] key_in;
    output [32 * Nk - 1:0] key_out;

    genvar i;

    // Split the key into Nk words
    wire [31:0] words[Nk - 1:0];

    generate
        for (i = 0; i < Nk; i = i + 1) begin: KeySplitLoop
            assign words[i] = key_in[(32 * Nk - 1) - i * 32 -: 32];
        end
    endgenerate

    // Rotate the words (rotWord)
    wire [31:0] w3Rot = {words[Nk - 1][23:0], words[Nk - 1][31:24]};

    // Perform the substitution of the words (subWord)
    wire [31:0] w3Sub;

    generate 
        for (i = 0; i < 4; i = i + 1) begin: SubWordLoop
            aes_sbox subTable(w3Rot[8 * i +: 8], w3Sub[8 * i +: 8]);
        end
    endgenerate

    // Perform the XOR operation with the round constant (roundConstant)
    wire [7:0] roundConstantStart = round_count == 1 ? 8'h01
                                        : round_count == 2 ? 8'h02
                                        : round_count == 3 ? 8'h04
                                        : round_count == 4 ? 8'h08
                                        : round_count == 5 ? 8'h10
                                        : round_count == 6 ? 8'h20
                                        : round_count == 7 ? 8'h40
                                        : round_count == 8 ? 8'h80
                                        : round_count == 9 ? 8'h1b
                                        : round_count == 10 ? 8'h36
                                        : round_count == 11 ? 8'h6c
                                        : round_count == 12 ? 8'hd8
                                        : round_count == 13 ? 8'hab
                                        : round_count == 14 ? 8'h4d
                                        : round_count == 15 ? 8'h9a
                                        : round_count == 16 ? 8'h2f
                                        : 8'h00;
    wire [31:0] roundConstant = {roundConstantStart, 24'h00};

    assign key_out[32 * Nk - 1 -: 32] = words[0] ^ w3Sub ^ roundConstant;

    // Perform SubWord transformation for i % Nk work (256 bits key only)
    wire [31:0] wSub;
    generate 
        for (i = 0; i < 4; i = i + 1) begin: SubWordLoopForWSub
            aes_sbox subTable(key_out[(32 * Nk - 1) - 3 * 32 - i * 8 -: 8], wSub[(3 - i) * 8 +: 8]);
        end
    endgenerate

    generate
        for (i = 1; i < Nk; i = i + 1) begin: KeyExpansionLoop
            assign key_out[(32 * Nk - 1) - i * 32 -: 32] = words[i] ^ (Nk == 8 && i == 4 ? wSub : key_out[(32 * Nk - 1) - (i - 1) * 32 -: 32]);
        end
    endgenerate
endmodule


// Sequential AES-128 key scheduler.
// Loads the original key, then generates round keys 1 through 10,
// one round key per clock. A new key can be loaded after READY.
module aes_key_expand (
    input  wire         clk,
    input  wire         reset,
    input  wire         start,
    input  wire [127:0] key,
    output reg  [1407:0] all_keys,
    output reg          ready
);
    localparam IDLE      = 2'b00;
    localparam EXPANDING = 2'b01;
    localparam READY     = 2'b10;

    reg [1:0] state;
    reg [3:0] round_count;
    reg [127:0] current_key;
    wire [127:0] next_round_key;

    aes_key_expand_round #(4, 10) round_unit (
        .round_count (round_count),
        .key_in      (current_key),
        .key_out     (next_round_key)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            round_count <= 4'd0;
            current_key <= 128'd0;
            all_keys    <= 1408'd0;
            ready       <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    if (start) begin
                        current_key <= key;
                        all_keys[1407:1280] <= key; // Round key 0
                        round_count <= 4'd1;
                        state <= EXPANDING;
                    end
                end

                EXPANDING: begin
                    all_keys[1407 - round_count*128 -: 128] <= next_round_key;
                    current_key <= next_round_key;

                    if (round_count == 4'd10) begin
                        ready <= 1'b1;
                        state <= READY;
                    end else begin
                        round_count <= round_count + 1'b1;
                    end
                end

                READY: begin
                    ready <= 1'b1;
                    if (start) begin
                        ready <= 1'b0;
                        current_key <= key;
                        all_keys[1407:1280] <= key;
                        round_count <= 4'd1;
                        state <= EXPANDING;
                    end
                end

                default: begin
                    state <= IDLE;
                    ready <= 1'b0;
                end
            endcase
        end
    end
endmodule
