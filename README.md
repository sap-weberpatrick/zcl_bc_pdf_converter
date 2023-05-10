# ZCL_BC_PDF_CONVERTER
ABAP class to convert PDF documents into images.
Both, PDF source file and resulting image file are stored temporary on application server. The conversion itself is done by system call to pdftoppm tool, wich is available under most unix systems these days.

# Prerequisit
Use transaction SM69 to define a system command Z_PDFTOPPM
![image](https://github.com/sap-weberpatrick/zcl_bc_pdf_converter/assets/26644498/c49cd363-955a-426d-a169-350bac343170)

# Usage
```
data: lv_data type xstring,
      lv_result type xstring,
      
      " get pdf stream from kpro or any other source.
      " you need pdf as xstring, not as file
      
          DATA(lo_converter) = NEW zcl_bc_pdf_converter(  ).
          lo_converter->set_source_data( lv_data ).
          lo_converter->convert(  ).
          lv_result = lo_converter->get_conversion_result(  ).
```
