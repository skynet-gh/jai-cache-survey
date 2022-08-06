#run build();

PROGRAM_TEXT :: #string DONE
noop_logger :: (message : string, data : *void, info : Log_Info) {
  // do nothing
}

main :: () {
  quiet := context;
  quiet.logger = noop_logger;
  before : u64;
  push_context quiet {
    before = rdtsc();
    bench();
  }
  cycles := rdtsc() - before;
  print("%", cycles);
}

#import "Basic";
#import "Machine_X64";
DONE

program_name :: (size_kb : u64, version : string) -> string {
  return copy_string(sprint("%-%", version, formatInt(size_kb, minimum_digits=6)));
}

ITER :: 17;

build :: () {
  size_kb : u64 = 1;

  versions : [2] string;
  versions[0] = "base";
  versions[1] = "bench";

  for i : 0..ITER {
    for version : versions {
      name := program_name(size_kb, version);
      print("Compiling %\n", name);

      w := compiler_create_workspace();

      options := get_build_options();
      options.output_executable_name = name;
      options.optimization_level     = .RELEASE;

      set_build_options(options, w);

      add_build_string(sprint("#import \"Cache_Survey\"(SIZE=%, BASELINE=%);\n", size_kb * 1024, version == "base"), w);
      add_build_string(PROGRAM_TEXT, w);
    }

    size_kb *= 2;
  }
}

N :: 10_000_000;

main :: () {
  size_kb : u64 = 1;

  versions : [2] string;
  versions[0] = "base";
  versions[1] = "bench";

  for i : 0..ITER {
    base_cycles : u64;
    bench_cycles : u64;
    for version : versions {
      name := program_name(size_kb, version);
      #if OS == .WINDOWS {
        exe_name := sprint("%.exe", name);
      } else {
        exe_name := name;
      }

      result, output, error := run_command(exe_name, capture_and_return_output=true);
      if result.exit_code == 0{
        cycles : u64 = parse_int(*output, u64);
        if version == "base"  base_cycles = cycles;  else  bench_cycles = cycles;
      }
    }

    if bench_cycles && base_cycles {
      diff := bench_cycles - base_cycles;

      print("% KiB cycles per iteration = %\n", formatInt(size_kb, minimum_digits=6), formatInt(diff / N, minimum_digits=3));
    } else {
      print("% KiB errored\n", size_kb);
    }

    size_kb *= 2;
  }
}

#import "Basic";
#import "Compiler";
#import "Process";
#import "String";
