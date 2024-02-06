// modules
include { GET_DOCKER_INFO as QC_DOCKER_INFO } from "../nf-submodules/modules/qc_report.nf"
include { GET_DOCKER_INFO as PDC_DOCKER_INFO } from "../nf-submodules/modules/pdc.nf"
include { GET_VERSION as ENCYCLOPEDIA_VERSION } from "../nf-submodules/modules/encyclopedia.nf"
include { GET_VERSION as PROTEOWIZARD_VERSIONS } from "../nf-submodules/modules/skyline.nf"

workflow export_version_info {

    take:
        fasta
        spectral_library
        mzml_files

    main:
        PDC_DOCKER_INFO()
        QC_DOCKER_INFO()
        PROTEOWIZARD_VERSIONS()
        ENCYCLOPEDIA_VERSION()

        mzml_basenames = mzml_files.map{ f -> f.getName() }
}

