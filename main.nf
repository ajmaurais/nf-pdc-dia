#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Sub workflows
include { get_pdc_files } from "./nf-submodules/workflows/get_pdc_files.nf"
include { skyline_import } from "./nf-submodules/workflows/skyline_import.nf"
include { get_input_files } from "./nf-submodules/workflows/get_input_files.nf"
include { encyclopedia_search } from "./nf-submodules/workflows/encyclopedia_search.nf"

workflow {
    get_input_files()
    get_pdc_files()

    // set up some convenience variables
    fasta = get_input_files.out.fasta
    spectral_library = get_input_files.out.spectral_library
    skyline_template_zipfile = get_input_files.out.skyline_template_zipfile
    wide_mzml_ch = get_pdc_files.out.wide_mzml_ch

    // search wide-window data using chromatogram library
    encyclopedia_search (
        wide_mzml_ch,
        fasta,
        spectral_library,
        true,
        "quant",
        params.encyclopedia.params
    )

    quant_elib = encyclopedia_search.out.final_elib

    // // create Skyline document
    // skyline_import(
    //     skyline_template_zipfile,
    //     fasta,
    //     quant_elib,
    //     wide_mzml_ch
    // )
}

