pub const CYCLES: u32 = 1000;
pub const WARMUP_CYCLES: u32 = 10;

pub fn expectedResizeCount(initial: u32, cycles: u32) u32 {
    return initial +% cycles;
}
