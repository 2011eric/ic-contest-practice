module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);
input clk;
input reset;
input [7:0] chardata;
input isstring;
input ispattern;

output reg       match      ;
output reg [4:0] match_index;
output reg 		 valid      ;


localparam STR_WIDTH = 32;
localparam PAT_WIDTH = 8;

localparam WORD_START = 8'h5E;
localparam WORD_END   = 8'h24;
localparam WORD_ANY   = 8'h2E;
localparam WORD_SPACE = 8'h20;



typedef enum logic [2:0] {
	IDLE,
    INPUT_STR,
	INPUT_PAT,
    MATCH
} state_e;

typedef logic [7:0] char_t;

// output registers
logic valid_r, valid_w;
logic match_r, match_w;
logic [4:0] match_index_r, match_index_w;

assign valid = valid_r;
assign match = match_r;
assign match_index = match_index_r;


// registers
state_e state_r, state_w;

char_t string_r [0:STR_WIDTH+1], string_w [0:STR_WIDTH+1];
char_t pattern_r [0:PAT_WIDTH-1], pattern_w [0:PAT_WIDTH-1];

logic [$clog2(PAT_WIDTH):0]     pat_cnt_r, pat_cnt_w;
logic [$clog2(STR_WIDTH+2):0]   str_cnt_r, str_cnt_w;

logic [$clog2(STR_WIDTH+2)-1:0]   s_cnt_r, s_cnt_w;
logic [$clog2(PAT_WIDTH)-1:0]     p_cnt_r, p_cnt_w;


always_comb begin : state_logic
    state_w = state_r;
    valid_w = 0;
    match_w = match_r;
    match_index_w = match_index_r;

    string_w  = string_r;
    pattern_w = pattern_r;

    str_cnt_w = str_cnt_r;
    pat_cnt_w = pat_cnt_r;

    s_cnt_w = s_cnt_r;
    p_cnt_w = p_cnt_r;

    unique case(state_r)
		IDLE: begin
			if (isstring) begin
				str_cnt_w  = 2;
				string_w[1] = chardata;
				state_w = INPUT_STR;
			end else if (ispattern) begin
				pat_cnt_w = 1;
				pattern_w[0] = chardata;
				state_w = INPUT_PAT;
			end
		end
        INPUT_STR: begin
            if (isstring) begin
                str_cnt_w = str_cnt_r + 1;
                string_w[str_cnt_r] = chardata;
                state_w = INPUT_STR;
			end else if (ispattern) begin
				state_w = INPUT_PAT;
                string_w[str_cnt_r] = WORD_SPACE;
                str_cnt_w = str_cnt_r + 1;
                pat_cnt_w = 1;
				pattern_w[0] = chardata;
			end
        end
		INPUT_PAT: begin
			if (ispattern) begin
				pattern_w[pat_cnt_r] = chardata;
                pat_cnt_w = pat_cnt_r + 1;
			end else begin
				state_w = MATCH;
                s_cnt_w = 0;
                p_cnt_w = 0;
			end
		end
        MATCH: begin
			p_cnt_w = p_cnt_r + 1;
            if(pattern_r[p_cnt_r] == WORD_START || pattern_r[p_cnt_r] == WORD_END) begin
                match_w = match_r && (string_r[s_cnt_r+p_cnt_r] == WORD_SPACE);
            end else if(pattern_r[p_cnt_r] != WORD_ANY) begin
                match_w = match_r && (string_r[s_cnt_r+p_cnt_r] == pattern_r[p_cnt_r]);
            end

            if(p_cnt_r == pat_cnt_r -1) begin
                p_cnt_w = 0;
                s_cnt_w = s_cnt_r + 1;

                if(match_w) begin
                    state_w = IDLE;
                    valid_w = 1;
                    match_index_w = s_cnt_r - (pattern_r[0] != WORD_START && s_cnt_r != 0);
                end else begin
                    match_w = 1;
                end


                if(s_cnt_r == str_cnt_r - pat_cnt_r + 2) begin
                    // NO MATCH
                    state_w = IDLE;
                    valid_w = 1;
                    match_w = 0;
                end
            end

        end
    endcase
end


















always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		state_r <= IDLE;
		match_r <= 0;
		match_index_r <= 0;
        valid_r <= 0;

        pat_cnt_r <= 0;
        str_cnt_r <= 0;
        string_r  <= '{default: WORD_SPACE};
        pattern_r <= '{default: WORD_SPACE};
        s_cnt_r <= 0;
        p_cnt_r <= 0;
	end else begin
        state_r <= state_w;
		match_r <= match_w;
		match_index_r <= match_index_w;
        valid_r <= valid_w;

        pat_cnt_r <= pat_cnt_w;
        str_cnt_r <= str_cnt_w;
        string_r  <= string_w;
        pattern_r <= pattern_w;
        s_cnt_r <= s_cnt_w;
        p_cnt_r <= p_cnt_w;
	end
end

endmodule
