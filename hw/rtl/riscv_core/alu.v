`include "Opcode.vh"
module  alu (
  a, b, opcode, funct3, funct7,
  branch, alu_res
);
input signed  [31:0] a;  
input signed  [31:0] b;
input [6:0]  opcode;
input [2:0]  funct3;
input [6:0]  funct7;

output reg branch;
output reg [31:0] alu_res;



always @(*) begin
  alu_res = 0;
  //add
  if ( 
    //R add
    ({opcode, funct3, funct7} == {`OPC_ARI_RTYPE, `FNC_ADD_SUB, 7'b0}) ||
    //I add
    ({opcode, funct3} == {`OPC_ARI_ITYPE, `FNC_ADD_SUB}) ||
    //Load add
    (opcode == `OPC_LOAD) ||
    //Store add
    (opcode == `OPC_STORE)
  ) 
    alu_res = a + b;
  //sub 
  else if(
    ({opcode, funct3, funct7} == {`OPC_ARI_RTYPE, `FNC_ADD_SUB, 7'h20})
  )
    alu_res = a - b;
  //xor ^
  else if(funct3 == `FNC_XOR)
    alu_res = a ^ b;
  //or |
  else if(funct3 == `FNC_OR)
    alu_res = a | b;
  //and &
  else if(funct3 == `FNC_AND)
    alu_res = a & b;
  //<<
  //For verilog shift The right operand is always treated as an unsigned number
  //Only need lower 5 bits of b
  else if(funct3 == `FNC_SLL)
    alu_res = a << b[4:0];
  //>> Right shift logic
  else if({funct3, funct7} == {`FNC_SRL_SRA, 7'b0})
    alu_res = a >> b[4:0];
  //>>> Arithmetic right shift
  else if({funct3, funct7} == {`FNC_SRL_SRA, 7'h20})
    alu_res = a >>> b[4:0];
  //set less than, alu_res = a < b ? 1 : 0
  else if(funct3 == `FNC_SLT)
    alu_res = a < b;
  //set less than unsigned
  //Verilog: Part-select results are unsigned, regardless of the operands
  else if(funct3 == `FNC_SLTU)
    alu_res = a[31:0] < b[31:0];
end


//Decide brach or not
always @(*) begin
  branch = 0;
  if (opcode == `OPC_BRANCH) begin
    case (funct3)
      `FNC_BEQ : branch = a==b;
      `FNC_BNE : branch = a!=b; 
      `FNC_BLT : branch = a<b; 
      `FNC_BGE : branch = a>=b; 
      `FNC_BLTU : branch = a[31:0]<b[31:0];
      `FNC_BGEU : branch = a[31:0]>=b[31:0]; 
    endcase
  end
end

endmodule