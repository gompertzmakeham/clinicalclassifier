Syphilis Assays
---------------

In this note we outline which records to select from `PREP_FINAL_LAB_MAY21` by filtering the
fields `ORDER_MNEMONIC` and `RESULT_TEST` for the assays:

* EIA
* Inno
* TPPA
* RPR

Each assay conducted on a collected sample can generate multiple records, where each record
contains part of the results or interpretation of the specific assay.

* Inno
  * `ORDER_MNEMONIC` = `.INNO SYPH`
  * `RESULT_TEST` = `Syphilis Inno-LIA Score`
* TPPA
  * `ORDER_MNEMONIC` = `.TPPA`
  * `RESULT_TEST` = `Syphilis TPPA`
* RPR
  * `ORDER_MNEMONIC` = `.RPR`
* EIA
  * Adult New
    * `ORDER_MNEMONIC` = `SYPH PROV`
    * `RESULT_TEST` = `Syphilis EIA`
  * Adult Old
    * `ORDER_MNEMONIC` = `SYPH`
    * `RESULT_TEST` = `SYPH`
  * Prenatal
    * `RESULT_TEST` = `Prenatal Syphilis EIA`
