`timescale 1ns/1ps
`default_nettype none

// 11-stage AES-128 pipeline:
// stage 0 = initial AddRoundKey
// stages 1..9 = SubBytes, ShiftRows, MixColumns, AddRoundKey
// stage 10 = SubBytes, ShiftRows, AddRoundKey (no MixColumns)
module aes128_pipeline_core (
    input  wire         clk,
    input  wire         reset,
    input  wire [127:0] plaintext,
    input  wire         load,
    input  wire [1407:0] all_keys,
    output reg  [127:0] ciphertext,
    output reg          ciphertext_valid
);
    reg [127:0] stage [0:10];
    reg [10:0] valid_pipe;

    wire [127:0] initial_state;
    aes_addroundkey initial_ark (
        .state     (plaintext),
        .round_key (all_keys[1407:1280]),
        .state_out (initial_state)
    );

    genvar r;
    generate
        for (r = 1; r <= 9; r = r + 1) begin : AES_ROUNDS
            wire [127:0] sb, sr, mc, ark;
            wire [127:0] round_key;

            assign round_key = all_keys[1407 - r*128 -: 128];

            aes_subbytes sub_bytes (
                .state     (stage[r-1]),
                .state_out (sb)
            );
            aes_shiftrows shift_rows (
                .state     (sb),
                .state_out (sr)
            );
            aes_mixcolumns mix_columns (
                .state_in  (sr),
                .state_out (mc)
            );
            aes_addroundkey add_round_key (
                .state     (mc),
                .round_key (round_key),
                .state_out (ark)
            );

            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    stage[r] <= 128'd0;
                    valid_pipe[r] <= 1'b0;
                end else begin
                    stage[r] <= ark;
                    valid_pipe[r] <= valid_pipe[r-1];
                end
            end
        end
    endgenerate

    wire [127:0] final_sb, final_sr, final_ark;
    aes_subbytes final_sub_bytes (
        .state     (stage[9]),
        .state_out (final_sb)
    );
    aes_shiftrows final_shift_rows (
        .state     (final_sb),
        .state_out (final_sr)
    );
    aes_addroundkey final_add_round_key (
        .state     (final_sr),
        .round_key (all_keys[127:0]),
        .state_out (final_ark)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            stage[0] <= 128'd0;
            valid_pipe[0] <= 1'b0;
            stage[10] <= 128'd0;
            valid_pipe[10] <= 1'b0;
            ciphertext <= 128'd0;
            ciphertext_valid <= 1'b0;
        end else begin
            if (load)
                stage[0] <= initial_state;
            valid_pipe[0] <= load;

            stage[10] <= final_ark;
            valid_pipe[10] <= valid_pipe[9];
            ciphertext <= final_ark;
            ciphertext_valid <= valid_pipe[9];
        end
    end
endmodule


// Transaction wrapper for one 128-bit block per start pulse.
// To encrypt a 256-bit SHA-256 digest, submit digest[255:128], wait
// for valid, then submit digest[127:0] using the same loaded key.
module aes128_top (
    input  wire         clk,
    input  wire         reset,

    input  wire         key_load,
    input  wire [127:0] key,
    output wire         key_ready,

    input  wire         start,
    input  wire [127:0] plaintext,

    output reg  [127:0] ciphertext,
    output reg          busy,
    output reg          done,
    output reg          valid,
    output wire         ready
);
    reg key_load_d;
    wire key_load_pulse = key_load & ~key_load_d & ~busy;

    always @(posedge clk or posedge reset) begin
        if (reset)
            key_load_d <= 1'b0;
        else
            key_load_d <= key_load;
    end

    wire [1407:0] all_keys;
    aes_key_expand key_scheduler (
        .clk      (clk),
        .reset    (reset),
        .start    (key_load_pulse),
        .key      (key),
        .all_keys (all_keys),
        .ready    (key_ready)
    );

    assign ready = key_ready && !busy && !key_load;

    wire core_load = start && ready;
    wire [127:0] core_ciphertext;
    wire core_valid;

    aes128_pipeline_core pipeline (
        .clk               (clk),
        .reset             (reset),
        .plaintext         (plaintext),
        .load              (core_load),
        .all_keys          (all_keys),
        .ciphertext        (core_ciphertext),
        .ciphertext_valid  (core_valid)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ciphertext <= 128'd0;
            busy <= 1'b0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            done <= 1'b0;
            valid <= 1'b0;

            if (core_load)
                busy <= 1'b1;

            if (core_valid) begin
                ciphertext <= core_ciphertext;
                busy <= 1'b0;
                done <= 1'b1;
                valid <= 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
