// When valid is high, generate next permutation, when finished, pull up ready
module perm_gen #(parameter N=8) (
    input clk,
    input rst,
    input valid,
    output reg ready,
    output [$clog2(N)-1:0] perm [0:N-1]
);


    typedef enum logic [2:0] {
        IDLE,
        FIND_PIVOT,
        FIND_SWAP,
        INVERT
    } state_e;

    typedef logic [$clog2(N)-1:0] num_t;

    reg ready_w;
    state_e state_r, state_w;
    num_t perm_r[0:N-1], perm_w[0:N-1];
    num_t perm_last_r [0:N-1], perm_last_w [0:N-1];
    num_t r0_r, r0_w, r1_r, r1_w;
    num_t r2_r, r2_w, r3_r, r3_w;
    num_t index_r, index_w;
    num_t perm_rddata, perm_rddata2;
    assign perm_rddata = perm_r[index_r];
    assign perm_rddata2 = perm_r[r0_r];
    logic swap;

    // r0 -> value of pivot
    // r1 -> number to swap in FIND_SWAP,
    //        in FIND_SWAP, keep track of minimum value larger than pivot
    // r2 -> index of pivot
    // r3 -> index of number to swap

    logic is_pivot;
    assign is_pivot = perm_rddata < r1_r;
    logic lock_r, lock_w;


    assign perm = perm_r;

    always_comb begin : array_wr
        perm_w = perm_r;

        if (swap) begin
            // swap current position
            if (state_r == FIND_SWAP) begin
                perm_w[r3_w] = r0_r;
                perm_w[r2_r] = r1_w;
            end else begin
                perm_w[index_r] = perm_rddata2;
                perm_w[r0_r] = perm_rddata;
            end
        end
    end

    always_comb begin : state_logic
        perm_last_w = perm_last_r;
        state_w = state_r;
        r0_w = r0_r;
        r1_w = r1_r;
        r2_w = r2_r;
        r3_w = r3_r;
        index_w = index_r;
        ready_w = ready;
        swap = 0;
        lock_w = lock_r;
        unique case (state_r)
            IDLE: begin
                if (valid) begin
                    state_w = FIND_PIVOT;
                    ready_w = 0;
                    index_w = 6;
                    r0_w = 0; // default to perm[7]
                    r1_w = perm_rddata;
                    r2_w = 0;
                    r3_w = 0;
                    lock_w = 0;
                end
            end
            FIND_PIVOT: begin
                index_w = index_r - 1;

                if (is_pivot) begin
                    state_w = FIND_SWAP;
                    index_w = index_r + 1;
                    r0_w = perm_rddata;
                    r3_w = index_r + 1;
                    r2_w = index_r;
                end else begin
                    r1_w = perm_rddata; // previous value
                end
                if (index_r == 3'(N-1)) begin
                    lock_w = 1;
                end
            end
            FIND_SWAP: begin
                index_w = index_r + 1;
                if (perm_rddata < r1_r && perm_rddata > r0_r && !lock_r) begin
                    r1_w = perm_rddata;
                    r3_w = index_r;
                end
                if (index_r == 3'(N-1)) begin
                    swap = 1;
                    state_w = INVERT;
                    r0_w = 3'(N-1);
                    index_w = r2_r + 1;
                end
            end
            INVERT: begin
                // i = pivot + 1
                // j = 7 = r1
                // while ( j > i)
                // swap(perm[j], perm[i])
                // i++;j--;
                if (r0_r > index_r) begin
                    swap = 1;
                    r0_w = r0_r - 1;
                    index_w = index_r + 1;
                end else begin
                    state_w = IDLE;
                    index_w = N-1;
                    ready_w = 1;
                    perm_last_w = perm_w;
                end
            end

        endcase

    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ready <= 1;
            state_r <= IDLE;
            perm_r <= '{default:0};
            perm_last_r <= '{default:0};
            r0_r <= 0;
            r1_r <= 0;
            r2_r <= 0;
            r3_r <= 0;
            index_r <= N-1;
            lock_r <= 0;
            for (int i = 0; i < N; i++)
                perm_r[i] <= i;
        end else begin
            ready <= ready_w;
            state_r <= state_w;
            perm_r <= perm_w;
            perm_last_r <= perm_last_w;
            r0_r <= r0_w;
            r1_r <= r1_w;
            r2_r <= r2_w;
            r3_r <= r3_w;
            index_r <= index_w;
            lock_r <= lock_w;
        end
    end



endmodule
