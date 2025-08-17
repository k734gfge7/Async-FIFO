module async_fifo #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 7  // 2^7 = 128 depth
)(
    input  wire                  wr_clk,
    input  wire                  rd_clk,
    input  wire                  rst_n,
    input  wire                  wr_en,
    input  wire                  rd_en,
    input  wire [DATA_WIDTH-1:0] din,
    output wire [DATA_WIDTH-1:0] dout,
    output wire                  full,
    output wire                  empty
);

    // Write and read pointers
    reg [ADDR_WIDTH-1:0] wr_ptr_bin = 0, wr_ptr_gray = 0;
    reg [ADDR_WIDTH-1:0] rd_ptr_bin = 0, rd_ptr_gray = 0;

    // Synchronizers for crossing domains
    reg [ADDR_WIDTH-1:0] wr_ptr_gray_rdclk1 = 0, wr_ptr_gray_rdclk2 = 0;
    reg [ADDR_WIDTH-1:0] rd_ptr_gray_wrclk1 = 0, rd_ptr_gray_wrclk2 = 0;

    // Memory
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // Convert binary to Gray code
    function [ADDR_WIDTH-1:0] bin2gray(input [ADDR_WIDTH-1:0] bin);
        bin2gray = bin ^ (bin >> 1);
    endfunction

    // Convert Gray code to binary
    function [ADDR_WIDTH-1:0] gray2bin(input [ADDR_WIDTH-1:0] gray);
        integer i;
        begin
            gray2bin[ADDR_WIDTH-1] = gray[ADDR_WIDTH-1];
            for (i = ADDR_WIDTH-2; i >= 0; i=i-1)
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
        end
    endfunction

    // Write pointer logic
    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr_bin <= 0;
        else if (wr_en && !full)
            wr_ptr_bin <= wr_ptr_bin + 1;
    end

    always @(posedge wr_clk) begin
        wr_ptr_gray <= bin2gray(wr_ptr_bin);
    end

    // Read pointer logic
    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr_bin <= 0;
        else if (rd_en && !empty)
            rd_ptr_bin <= rd_ptr_bin + 1;
    end

    always @(posedge rd_clk) begin
        rd_ptr_gray <= bin2gray(rd_ptr_bin);
    end

    // Synchronize write pointer into read clock domain
    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr_gray_rdclk1 <= 0;
            wr_ptr_gray_rdclk2 <= 0;
        end else begin
            wr_ptr_gray_rdclk1 <= wr_ptr_gray;
            wr_ptr_gray_rdclk2 <= wr_ptr_gray_rdclk1;
        end
    end

    // Synchronize read pointer into write clock domain
    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr_gray_wrclk1 <= 0;
            rd_ptr_gray_wrclk2 <= 0;
        end else begin
            rd_ptr_gray_wrclk1 <= rd_ptr_gray;
            rd_ptr_gray_wrclk2 <= rd_ptr_gray_wrclk1;
        end
    end

    // Full and empty flags
    assign full  = (bin2gray(wr_ptr_bin + 1) == {~rd_ptr_gray_wrclk2[ADDR_WIDTH-1:ADDR_WIDTH-2], rd_ptr_gray_wrclk2[ADDR_WIDTH-3:0]});
    assign empty = (rd_ptr_gray == wr_ptr_gray_rdclk2);

    // Memory write
    always @(posedge wr_clk) begin
        if (wr_en && !full)
            mem[wr_ptr_bin] <= din;
    end

    // Memory read
    assign dout = mem[rd_ptr_bin];

endmodule
