#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Sub workflows
include { get_pdc_files; get_pdc_study_metadata } from "./nf-submodules/workflows/get_pdc_files.nf"
include { skyline_import } from "./nf-submodules/workflows/skyline_import.nf"
include { get_input_files } from "./nf-submodules/workflows/get_input_files.nf"
include { encyclopedia_search } from "./nf-submodules/workflows/encyclopedia_search.nf"
include { get_mzml_files } from "./nf-submodules/workflows/get_ms_data_files.nf"
include { generate_dia_qc_report } from "./nf-submodules/workflows/generate_qc_report.nf"
include { s3_upload } from "./nf-submodules/workflows/s3_transfer.nf"
include { export_version_info } from './workflows/export_version_info.nf'

// modules
include { UNZIP_SKY_FILE } from "./nf-submodules/modules/skyline.nf"
include { SKYLINE_ANNOTATE_DOCUMENT } from "./nf-submodules/modules/skyline.nf"
include { PANORAMA_IMPORT_SKYLINE } from "./nf-submodules/modules/panorama.nf"
include { PANORAMA_UPLOAD_FILE as UPLOAD_QC_REPORTS } from "./nf-submodules/modules/panorama.nf"

workflow {

    // get mzml files
    if(params.ms_data_dir == null) {
        get_pdc_files()
        wide_mzml_ch = get_pdc_files.out.wide_mzml_ch
        annotations_csv = get_pdc_files.out.annotations_csv
        metadata = get_pdc_files.out.metadata
    } else {
        get_pdc_study_metadata()
        get_mzml_files(params.ms_data_dir, '*', 'raw')
        wide_mzml_ch = get_mzml_files.out.mzml_ch
        annotations_csv = get_pdc_study_metadata.out.annotations_csv
        metadata = get_pdc_study_metadata.out.metadata
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

    encyclopedia_search_output = encyclopedia_search.out.elib

    quant_elib = encyclopedia_search.out.elib

    // create Skyline document
    skyline_import(
        skyline_template_zipfile,
        fasta,
        quant_elib,
        wide_mzml_ch
    )

    // Annotate Skyline document
    UNZIP_SKY_FILE(skyline_import.out.skyline_results)
    SKYLINE_ANNOTATE_DOCUMENT(UNZIP_SKY_FILE.out.sky_file,
                              UNZIP_SKY_FILE.out.sky_artifacts.collect(),
                              annotations_csv)

    // Import Skyline document to Panorama
    if( params.panorama.skyline_folder != null ) {
        PANORAMA_IMPORT_SKYLINE(params.panorama.skyline_folder,
                                SKYLINE_ANNOTATE_DOCUMENT.out.sky_zip_file)
    }

    // Export other reports


    // Generate and upload QC report
    generate_dia_qc_report(UNZIP_SKY_FILE.out.sky_file,
                           UNZIP_SKY_FILE.out.sky_artifacts.collect(),
                           "${params.pdc_study_id}",
                           "${params.pdc_study_id} DIA QC report",
                           annotations_csv)

    if( params.panorama.reports_folder != null ) {
        UPLOAD_QC_REPORTS(params.panorama.reports_folder
                          generate_dia_qc_report.out.qc_reports)
    }

    qc_reports = generate_dia_qc_report.out.qc_reports.concat(
        generate_dia_qc_report.out.qc_report_qmd,
        generate_dia_qc_report.out.qc_report_db
    )

    // upload results to s3
    if( params.s3_upload.bucket_name != null ) {
        s3_upload(
            wide_mzml_ch,
            encyclopedia_search.out.search_files,
            encyclopedia_search.out.elib,
            skyline_import.out.skyd_files,
            SKYLINE_ANNOTATE_DOCUMENT.out.sky_zip_file,
            qc_reports
        )
    }

    // export version information
    export_version_info(fasta, spectral_library, wide_mzml_ch)
}

