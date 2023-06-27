#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Sub workflows
include { get_pdc_files } from "./nf-submodules/workflows/get_pdc_files"
include { encyclopedia_quant } from "./workflows/encyclopedia_quant"
include { get_wide_mzmls } from "./workflows/get_wide_mzmls"
include { skyline_import } from "./workflows/skyline_import"

workflow {
    get_input_files()
    get_pdc_files()

    // set up some convenience variables
    fasta = get_input_files.out.fasta
    spectral_library = get_input_files.out.spectral_library
    skyline_template_zipfile = get_input_files.out.skyline_template_zipfile
    wide_mzml_ch = get_wide_mzmls.out.wide_mzml_ch

    // // search wide-window data using chromatogram library
    // encyclopedia_quant(
    //     wide_mzml_ch, 
    //     fasta, 
    //     spectral_library
    // )

    // quant_elib = encyclopedia_quant.out.final_elib

    // // create Skyline document
    // skyline_import(
    //     skyline_template_zipfile,
    //     fasta,
    //     quant_elib,
    //     wide_mzml_ch
    // )
}

