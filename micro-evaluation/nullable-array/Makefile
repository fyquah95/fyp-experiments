all: bench.native

ifneq (,$(findstring fyp,$(shell which ocamlopt.opt)))
ADDITIONAL_OCAML_FLAGS=-inlining-overrides overrides.sexp
endif

bench.native: nullable_array_interface.mli nullable_array_closure.mli nullable_array_marker.mli  option_array.mli micro_bench_types.ml nullable_array_marker.ml  option_array.ml nullable_array_closure.ml  nullable_array_benchmark.ml

	ocamlopt.opt -dflambda -inline-max-depth 5 -inline-max-unroll 5 -inlining-report \
	  $(ADDITIONAL_OCAML_FLAGS) -O3 -S -o $@ $^ 1>stdout.log 2>flambda.out

clean:
	echo '()' >overrides.sexp
	rm -rf *.cm* *.native *.o *.data_collector.sexp stdout.log flambda.out *.inlining.org *.s
