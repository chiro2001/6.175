import Vector :: *;

function Bit#(32) shiftRightPow2(Bit#(1) en, Bit#(32) unshifted, Integer power);
    Integer distance = 2**power;
    Bit#(32) shifted = 0;
    if (en == 0) begin
        return unshifted;
    end else begin
        for (Integer i = 0; i < 32; i = i + 1) begin
            if (i + distance < 32) begin
                shifted[i] = unshifted[i + distance];
            end
        end
        return shifted;
    end
endfunction

// 代码风格：OpenTitan
// spaces ~2/~ 4
// lint? formatter? for bsv

// Exercise 6 (2017)
function Bit#(32) barrelShifterRight(Bit#(32) in, Bit#(5) shiftBy);
    // or: use Vector#(6) and return shifted[5]
    // 重复“赋值”?
    Bit#(32) shifted = in; // 编译阶段重复，elabration 阶段展开
    //                                      begin is requred
    for (Integer i = 0; i < 5; i = i + 1) begin
        shifted = shiftRightPow2(shiftBy[i], shifted, i);
    end
    return shifted;
endfunction


// 类型系统，类似 Haskell
// n: 小写，类型变量（指可变类型）
// 5: 数字也是一种类型；valueOf(5) 就是将类型转换为值