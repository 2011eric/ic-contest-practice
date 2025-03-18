module JAM (
input CLK,
input RST,
output reg [2:0] W,
output reg [2:0] J,
input [6:0] Cost,
output reg [3:0] MatchCount,
output reg [9:0] MinCost,
output reg Valid );


localparam N = 8;
localparam N_fact = 40320;


typedef enum logic {
	S_PERMUT,
	S_CALC_COST
} state_e;

state_e state_r, state_w;

logic [$clog2(40320):0] cnt_r, cnt_w;
logic [$clog2(N):0] cost_cnt_r, cost_cnt_w;

logic [3:0] MatchCount_r, MatchCount_w;
logic [9:0] MinCost_r, MinCost_w;
logic [9:0] TempCost_r, TempCost_w;
logic Valid_r, Valid_w;


logic perm_next;
logic perm_ready;
logic [$clog2(N)-1:0] perm [0:N-1], perm_r[0:N-1], perm_w[0:N-1];


assign W = cost_cnt_r[$clog2(N)-1:0];
assign J = perm_r[cost_cnt_r[$clog2(N)-1:0]];
assign Valid = Valid_r;
assign MatchCount = MatchCount_r;
assign MinCost = MinCost_r;


perm_gen #(.N(N)) perm_gen_inst (
	.clk(CLK),
    .rst(RST),
    .valid(perm_next),
    .ready(perm_ready),
    .perm(perm)
);

always_comb begin
	state_w = state_r;
	cnt_w = cnt_r;
	cost_cnt_w = cost_cnt_r;

	MatchCount_w = MatchCount_r;
	MinCost_w = MinCost_r;
	TempCost_w = TempCost_r;
	Valid_w = 0;

	perm_next = 0;
	perm_w = perm_r;
	unique case(state_r)

		S_PERMUT: begin
			if(perm_ready) begin
				cnt_w = cnt_r + 1;
				state_w = S_CALC_COST;
				cost_cnt_w = 0;
				TempCost_w = 0;
				perm_w = perm;
			end// else begin
				perm_next = 1;
			//end
		end

		S_CALC_COST: begin
			cost_cnt_w = cost_cnt_r + 1;

			TempCost_w = (cost_cnt_r == 0) ? 0 : TempCost_r + Cost;

			if(cost_cnt_r == N) begin
				state_w = S_PERMUT;

				if(TempCost_w < MinCost_r) begin
					MinCost_w = TempCost_w;
					MatchCount_w = 1;
				end else if(TempCost_w == MinCost_r) begin
					MatchCount_w = MatchCount_r + 1;
				end

				if(cnt_r == N_fact-1) begin
					state_w = S_PERMUT;
					Valid_w = 1;
				end
			end
		end
	endcase
end



always_ff @(posedge CLK or posedge RST) begin
	if(RST) begin
		state_r <= S_CALC_COST;
		cnt_r <= 0;
		cost_cnt_r <= 0;
		MatchCount_r <= 0;
		MinCost_r <= 10'h3FF;
		perm_r <= '{default:0};
		// TempCost_r <= 10'h3FF;
		TempCost_r <= 0;
		Valid_r <= 0;
	end else begin
		state_r <= state_w;
		cnt_r <= cnt_w;
		cost_cnt_r <= cost_cnt_w;
		MatchCount_r <= MatchCount_w;
		MinCost_r <= MinCost_w;
		TempCost_r <= TempCost_w;
		Valid_r <= Valid_w;
		perm_r <= perm_w;
	end
end



endmodule


