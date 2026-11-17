`timescale 1ns/1ps

module aes128_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg reset;
    reg key_load;
    reg [127:0] key;
    reg start;
    reg [127:0] plaintext;

    wire [127:0] ciphertext;
    wire busy, done, valid, ready, key_ready;

    aes128_top dut (
        .clk        (clk),
        .reset      (reset),
        .key_load   (key_load),
        .key        (key),
        .key_ready  (key_ready),
        .start      (start),
        .plaintext  (plaintext),
        .ciphertext (ciphertext),
        .busy       (busy),
        .done       (done),
        .valid      (valid),
        .ready      (ready)
    );

    task encrypt_and_check;
        input [127:0] test_plaintext;
        input [127:0] expected_ciphertext;
        begin
            @(negedge clk);
            while (!ready) @(negedge clk);
            plaintext = test_plaintext;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            wait(valid === 1'b1);
            if (ciphertext !== expected_ciphertext) begin
                $display("FAIL: P=%032h Expected=%032h Actual=%032h",
                         test_plaintext, expected_ciphertext, ciphertext);
                $finish;
            end else begin
                $display("PASS: P=%032h C=%032h",
                         test_plaintext, ciphertext);
            end
            @(negedge clk);
        end
    endtask

    initial begin
        reset = 1'b1;
        key_load = 1'b0;
        key = 128'd0;
        start = 1'b0;
        plaintext = 128'd0;

        repeat (3) @(negedge clk);
        reset = 1'b0;

        // FIPS-197 AES-128 known-answer test.
        key = 128'h000102030405060708090a0b0c0d0e0f;
        key_load = 1'b1;
        @(negedge clk);
        key_load = 1'b0;

        wait(key_ready === 1'b1);

        encrypt_and_check(
            128'h00112233445566778899aabbccddeeff,
            128'h69c4e0d86a7b0430d8cdb78070b4c55a
        );

        // Second standard AES-128 test vector (same key schedule is reloaded).
        // Load the second key, then verify the second independent transaction.
        @(negedge clk);
        key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        key_load = 1'b1;
        @(negedge clk);
        key_load = 1'b0;
        wait(key_ready === 1'b1);

        encrypt_and_check(
            128'h6bc1bee22e409f96e93d7e117393172a,
            128'h3ad77bb40d7a3660a89ecaf32466ef97
        );

        $display("All AES-128 known-answer tests passed.");
        $finish;
    end
endmodule
