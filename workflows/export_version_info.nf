// modules
include { GET_DOCKER_INFO as QC_DOCKER_INFO } from "../nf-submodules/modules/qc_report.nf"
include { GET_DOCKER_INFO as PDC_DOCKER_INFO } from "../nf-submodules/modules/pdc.nf"
include { GET_VERSION as ENCYCLOPEDIA_VERSION } from "../nf-submodules/modules/encyclopedia.nf"
include { GET_VERSION as PROTEOWIZARD_VERSIONS } from "../nf-submodules/modules/skyline.nf"

process WRITE_VERSION_INFO {
    publishDir "${params.result_dir}/", failOnError: true, mode: 'copy'
    container 'mauraisa/aws_bash:0.5'

    input:
        val var_names
        val values

    output:
        path("DIA_CDAP_versions.txt")

    shell:
        '''
        var_names=( '!{var_names.join("' '")}' )
        values=( '!{values.join("' '")}' )

        for i in ${!var_names[@]} ; do
            echo "${var_names[$i]}: ${values[$i]}" >> DIA_CDAP_versions.txt
        done
        '''
}

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

        workflow_var_names = Channel.fromList(['Workflow git info', 'Workflow cmd'])
        workflow_values = Channel.fromList(["${workflow.repository} - ${workflow.revision} [${workflow.commitId}]",
                                            workflow.commandLine])

        mzml_var_names = mzml_files.map{ f -> "Spectra File" }
        mzml_basenames = mzml_files.map{ f -> f.getName() }

        version_var_names = workflow_var_names.concat(mzml_var_names)
        version_values = workflow_values.concat(mzml_basenames)


        WRITE_VERSION_INFO(version_var_names.collect(), version_values.collect())
}

