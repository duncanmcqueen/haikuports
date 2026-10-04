#!/bin/bash
# Phase 4 validation of the installed rust_bin. Writes a "Tested on" record.
export LIBRARY_PATH='%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib'
L=~/rust/validation.log; W=/tmp/rv; rm -rf $W; mkdir -p $W; : > $L
run() { echo "\$ $*" >> $L; "$@" >> $L 2>&1; local rc=$?; echo "[exit $rc]" >> $L; echo >> $L; return $rc; }
echo "Haiku: $(uname -a)" >> $L
echo "Package: $(pkgman search -i -D rust_bin | tail -1 | tr -s ' ')" >> $L; echo >> $L
run rustc --version --verbose
run cargo --version
run rustdoc --version
run cargo clippy --version
run cargo fmt --version
cd $W
printf 'fn main() { println!("Hello from Rust {} on Haiku", env!("CARGO_PKG_VERSION")); }\n' > hello.rs
run rustc -O hello.rs -o hello && run ./hello
run cargo new --lib demo
cd demo
cat > src/lib.rs <<'RS'
/// Adds two numbers.
///
/// ```
/// assert_eq!(demo::add(2, 2), 4);
/// ```
pub fn add(a: u64, b: u64) -> u64 { a + b }

#[cfg(test)]
mod tests {
    use super::*;
    use std::{fs::File, io::Write, thread};

    #[test]
    fn adds() { assert_eq!(add(2, 3), 5); }

    #[test]
    fn threads_and_files() {
        let h: Vec<_> = (0..4).map(|i| thread::spawn(move || i * 2)).collect();
        let s: u64 = h.into_iter().map(|t| t.join().unwrap()).sum();
        assert_eq!(s, 12);
        let p = std::env::temp_dir().join("rv-lock-test");
        let mut f = File::create(&p).unwrap();
        f.write_all(b"x").unwrap();
        f.lock().unwrap();      // std File::lock (flock on Haiku)
        f.unlock().unwrap();
    }
}
RS
run cargo test
run cargo clippy -- -D warnings
run cargo fmt --check
run cargo doc --no-deps
cd $W
run cargo new pm
cd pm
cat >> Cargo.toml <<'T'
serde = { version = "1", features = ["derive"] }
serde_json = "1"
T
cat > src/main.rs <<'RS'
use serde::{Deserialize, Serialize};
#[derive(Serialize, Deserialize, Debug, PartialEq)]
struct P { name: String, v: u32 }
fn main() {
    let p = P { name: "haiku".into(), v: 199 };
    let s = serde_json::to_string(&p).unwrap();
    let q: P = serde_json::from_str(&s).unwrap();
    assert_eq!(p, q);
    println!("{s}");
}
RS
run cargo run --release
echo "VALIDATION DONE" >> $L
