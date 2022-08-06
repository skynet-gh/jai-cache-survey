#run build();

PROGRAM_TEXT :: #string DONE
noop_logger :: (message : string, data : *void, info : Log_Info) {
  // do nothing
}

main :: () {
  before := rdtsc();
  bench();
  cycles := rdtsc() - before;
  print("%", cycles);
}

#import "Basic";
#import "Machine_X64";
DONE

program_name :: (program_prefix : string, size_kb : u64, version : string) -> string {
  return copy_string(sprint("%-%-%", program_prefix, version, formatInt(size_kb, minimum_digits=6)));
}

INVALID_RDTSC : u64 : 10_000_000_000_000_000_000;

ITER :: 17;

VERSIONS :: string.["base", "bench"];

build :: () {
  build("sequential-access", "#import \"Access\"(SIZE=%, BASELINE=%, N=%, SHUFFLE=false);\n");
  build("random-access", "#import \"Access\"(SIZE=%, BASELINE=%, N=%, SHUFFLE=true);\n");
}

build :: (program_prefix : string, import_format : string) {
  size_kb : u64 = 1;

  for i : 0..ITER {
    for version : VERSIONS {
      name := program_name(program_prefix, size_kb, version);
      print("Compiling %\n", name);

      w := compiler_create_workspace();

      options := get_build_options();
      options.output_executable_name = name;
      options.optimization_level     = .RELEASE;

      set_build_options(options, w);

      add_build_string(sprint(import_format, size_kb * 1024, version == "base", N), w);
      add_build_string(PROGRAM_TEXT, w);
    }

    size_kb *= 2;
  }
}

N :: 100_000_000;

Result :: struct {
  x : u64;
  y : float64;
  total : float64;
  baseline : float64;
}

Compare :: struct {
  i : s64;
  x : u64;
  change : float64;
  slope : float64;
}

divided_by_N :: (x : u64) -> float64 {
  return (cast(float64) x) / cast(float64) N;
}

exe_if_windows :: (command : string) -> string {
  #if OS == .WINDOWS {
    return sprint("%.exe", command);
  } else {
    return command;
  }
}

main :: () {
  benchmark("sequential-access");
  benchmark("random-access");
}

benchmark :: (program_prefix : string) {
  print("\n\n\nBenchmarking %\n\n", program_prefix);

  size_kb : u64 = 1;

  results : [ITER+1] Result;

  for i : 0..ITER {
    result : Result;

    base_cycles : u64;
    bench_cycles : u64;
    for version : VERSIONS {
      exe_name := sprint("./%", exe_if_windows(program_name(program_prefix, size_kb, version)));

      while true {
        result, output, error := run_command(exe_name, capture_and_return_output=true);
        if result.exit_code == 0 {
          cycles : u64 = parse_int(*output, u64);
          if version == "base"  base_cycles = cycles;  else  bench_cycles = cycles;
          if cycles < INVALID_RDTSC  break;  else  print("Retrying bad result: %\n", cycles);
        } else  break;
      }
    }

    if bench_cycles && base_cycles {
      diff := bench_cycles - base_cycles;

      result.x = size_kb * 1024;

      if base_cycles > bench_cycles {
        print("Bad result: base=% higher than bench=%\n", base_cycles, bench_cycles);
        continue;
      } else if diff / N > 2000 {
        print("Retrying bad result: base=% bench=%\n", base_cycles, bench_cycles);
        i -= 1;
        continue;
      } else {
        result.total = divided_by_N(bench_cycles);
        result.baseline = divided_by_N(base_cycles);
        result.y = divided_by_N(diff);

        print("% KiB cycles per iteration = % (base=%, bench=%)\n", formatInt(size_kb, minimum_digits=6), formatInt(diff / N, minimum_digits=3), base_cycles, bench_cycles);
      }

      results[i] = result;
    } else {
      print("% KiB errored\n", formatInt(size_kb, minimum_digits=6));
    }

    size_kb *= 2;
  }

  l1_size : u64 = 32 * 1024;
  l2_size : u64 = 512 * 1024;

  print("\nResults done, attempting to plot with latex\n\n");

  tex_file_builder : String_Builder;
  init_string_builder(*tex_file_builder);

  major_tick_builder : String_Builder;

  tick : u64 = 2048;
  for i : 0..8 {
    if tick != l1_size && tick != l2_size  append(*major_tick_builder, sprint("%, ", tick));

    tick *= 4;
  }

  append(*tex_file_builder, sprint(TEX_FILE_PREFIX, builder_to_string(*major_tick_builder), l1_size, l2_size));
  for r : results {
    append(*tex_file_builder, sprint("      %, %, %, %\n", r.x, r.y, r.total, r.baseline));
  }
  append(*tex_file_builder, TEX_FILE_SUFFIX);

  tex_filename := sprint("%.tex", program_prefix);

  write_entire_file(tex_filename, builder_to_string(*tex_file_builder));

  print("Wrote latex file: %\n", tex_filename);

  pdf_filename := sprint("%.pdf", program_prefix);
  {
    command := exe_if_windows("pdflatex");
    arg := "-interaction=nonstopmode";
    print("% % %\n", command, arg, tex_filename);
    result, output, error := run_command(command, arg, tex_filename, capture_and_return_output=true);
    if result.exit_code == 0 {
      print("PDF file: %\n", pdf_filename);
    } else {
      print("Error running %: % % %\n", command, result, output, error);
    }
  }

  #if OS != .WINDOWS {
    cropped_pdf_filename := sprint("%-crop.pdf", program_prefix);
    {
      command := exe_if_windows("pdfcrop");
      filename := pdf_filename;
      result, output, error := run_command(command, filename, capture_and_return_output=true);
      if result.exit_code == 0 {
        print("% %\n", command, filename);
      } else {
        print("Error running %: % % %\n", command, result, output, error);
      }
    }

    svg_filename := sprint("%.svg", program_prefix);
    {
      command := exe_if_windows("pdf2svg");
      filename := cropped_pdf_filename;
      print("% %\n", command, filename);
      result, output, error := run_command(command, filename, svg_filename, capture_and_return_output=true);
      if result.exit_code == 0 {
        print("SVG file: %\n", svg_filename);
      } else {
        print("Error running %: % % %\n", command, result, output, error);
      }
    }
  }
}


TEX_FILE_PREFIX :: #string DONE
\documentclass[tikz, border=1pt]{standalone}

\pagestyle{empty}

\usetikzlibrary{datavisualization}

\def\kibtypesetter#1{
   \pgfmathfloatparsenumber{#1}
   \pgfmathfloattoint{\pgfmathresult}
   \pgfmathsetmacro{\a}{\pgfmathresult}
   \newcount\b
   \b=\number\a
   \divide\b by 1024
   \pgfmathprintnumber{\the\b}
}

\def\emphkibtypesetter#1{
   \ensuremath{\mathbf{\kibtypesetter{#1}}}
}

\tikzdatavisualizationset{
   array size vs cycles plot/.style={
      scientific axes=clean,
      x axis={
         logarithmic,
         ticks={
            /pgf/number format/int detect,
            major={
               tick typesetter/.code=\kibtypesetter{####1},
               at={
                  %1
                  %2 as \emphkibtypesetter{%2},
                  %3 as \emphkibtypesetter{%3},
               },
            },
            minor at={4096, 16384, 65536, 262144, 1048576, 4194304, 16777216, 67108864},
         },
         grid={at={%2, %3}},
         label={Array Size (KiB)},
         length=0.8\textwidth,
      },
      y axis={
        include value=0,
        label={Cycles / Iteration},
        length=6cm,
        grid=at ticks
      },
      visualize as scatter,
      scatter={style={mark=*, mark options={scale=.65}}},
   },
}

\pgfkeys{
    /pgf/number format/.cd,
    1000 sep={\,},
    min exponent for 1000 sep=4,
}

\begin{document}
\tikz \datavisualization[array size vs cycles plot]
    data {
      x, y, total, baseline
DONE

TEX_FILE_SUFFIX :: #string DONE
    };
\end{document}
DONE

#import "Basic";
#import "Compiler";
#import "File";
#import "Process";
#import "String";
