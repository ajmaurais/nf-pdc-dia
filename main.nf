#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Sub workflows
include { get_pdc_files; get_pdc_study_metadata } from "./nf-submodules/workflows/get_pdc_files.nf"
include { skyline_import } from "./nf-submodules/workflows/skyline_import.nf"
include { get_input_files } from "./nf-submodules/workflows/get_input_files.nf"
include { encyclopedia_search } from "./nf-submodules/workflows/encyclopedia_search.nf"
include { get_mzml_files } from "./nf-submodules/workflows/get_ms_data_files.nf"

// modules
include {SKYLINE_ANNOTATE_DOCUMENT} from "./nf-submodules/modules/skyline.nf"

workflow {

    // get mzml files
    if(params.ms_data_dir == null) {
        get_pdc_files()
        wide_mzml_ch = get_pdc_files.out.wide_mzml_ch
        annotations_csv = get_pdc_files.out.annotations_csv
    } else {
        get_pdc_study_metadata()
        get_mzml_files(params.ms_data_dir, '*', 'raw')
        wide_mzml_ch = get_mzml_files.out.mzml_ch
        annotations_csv = get_pdc_study_metadata.out.annotations_csv
    }

    // get fasta, spectral library, and Skyline template.
    get_input_files()

    // set up some convenience variables
    fasta = get_input_files.out.fasta
    spectral_library = get_input_files.out.spectral_library
    skyline_template_zipfile = get_input_files.out.skyline_template_zipfile

    // search wide-window data using chromatogram library
    encyclopedia_search (
        wide_mzml_ch,
        fasta,
        spectral_library,
        true,
        "quant",
        params.encyclopedia.params
    )

    quant_elib = encyclopedia_search.out.elib

    // create Skyline document
    skyline_import(
        skyline_template_zipfile,
        fasta,
        quant_elib,
        wide_mzml_ch
    )

    // Annotate Skyline document
    SKYLINE_ANNOTATE_DOCUMENT(skyline_import.out.skyline_results, annotations_csv)

    // Import Skyline document to Panorama

    // Export reports

    // Generate and upload QC report
}

