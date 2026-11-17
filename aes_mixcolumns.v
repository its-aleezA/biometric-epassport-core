
module aes_mixcolumns(state_in, state_out);
	input [127:0] state_in;
	output [127:0] state_out;

	// Function to multiply by 2 and fix the overflow
	function [7:0] xtime;
		input [7:0] in;
		if(in[7] == 1) xtime = (in << 1) ^ 8'h1B;
		else xtime = in << 1;
	endfunction

	genvar i;
	generate
		for(i = 0; i < 4; i = i + 1)begin: mixColumnsLoop
			// state[0,c] = 2*state[0,c] + (2 * state[1,c] + state[1,c]) + state[2,c] + state[3,c]
			assign state_out[32*i+24+:8] =  xtime(state_in[32*i+24+:8]) ^ (xtime(state_in[32*i+16+:8]) ^ state_in[32*i+16+:8]) ^ state_in[32*i+8 +:8] ^ state_in[32*i   +:8];
			
			// state[1,c] = 2*state[1,c] + (2 * state[2,c] + state[2,c]) + state[3,c] + state[0,c]
			assign state_out[32*i+16+:8] =  xtime(state_in[32*i+16+:8]) ^ (xtime(state_in[32*i+8 +:8]) ^ state_in[32*i+8 +:8]) ^ state_in[32*i   +:8] ^ state_in[32*i+24+:8];
			
			// state[2,c] = 2*state[2,c] + (2 * state[3,c] + state[3,c]) + state[0,c] + state[1,c]
			assign state_out[32*i+8 +:8] =  xtime(state_in[32*i+8 +:8]) ^ (xtime(state_in[32*i   +:8]) ^ state_in[32*i   +:8]) ^ state_in[32*i+24+:8] ^ state_in[32*i+16+:8];
			
			// state[3,c] = 2*state[3,c] + (2 * state[0,c] + state[0,c]) + state[1,c] + state[2,c]
			assign state_out[32*i   +:8] =  xtime(state_in[32*i   +:8]) ^ (xtime(state_in[32*i+24+:8]) ^ state_in[32*i+24+:8]) ^ state_in[32*i+16+:8] ^ state_in[32*i+8 +:8];
		end
	endgenerate
endmodule

