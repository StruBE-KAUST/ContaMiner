XML_TEMPLATE="""<?xml version="1.0" encoding="ASCII" standalone="yes"?>
<model_prep>
  <sequence>
    <n_structure>1</n_structure>
    <structure>
      <PDB_code>%PDB_CODE%</PDB_code>
      <model>
        <complex>100</complex>
        <chain>A</chain>
        <domain>0</domain>
        <similarity>1.000</similarity>
        <nmon>0</nmon>
        <coordinates file_crd="%FILE_NAME%"/>
      </model>
    </structure>
  </sequence>
</model_prep>"""
