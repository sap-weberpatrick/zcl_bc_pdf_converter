"!<p class="shorttext synchronized">PDF konvertieren mittels OS Tools</p>
"! Klasse zum konvertieren von PDF Dokumenten in andere Dateiformate
"!
"! Zum konvertieren müssen die Methoden
"! set_source_data
"! convert und
"! get_conversion_result
"!
"! aufgerufen werden. Die weiteren Methoden sind optional. Die
"! Konvertierung wird standardmäßig unter /tmp durchgeführt.
CLASS zcl_bc_pdf_converter DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS:
      "! <p class="shorttext synchronized">Dateityp PNG</p>
      c_convert_png TYPE i VALUE 0,
      "! <p class="shorttext synchronized">Dateityp TIF</p>
      c_convert_tif TYPE i VALUE 1,
      "! <p class="shorttext synchronized">Dateityp JPG</p>
      c_convert_jpg TYPE i VALUE 2.

    METHODS:
      "!<p class="shorttext synchronized">Zielformat setzen</p>
      "! @parameter iv_format     | <p class="shorttext synchronized">Zielformat, siehe C_CONVERT_PNG</p>
      "! @raising cx_invalid_format | <p class="shorttext synchronized"> Ungültiges Zielformat </p>
      set_target_format IMPORTING iv_format TYPE i RAISING cx_invalid_format,

      "!<p class="shorttext synchronized">Name der Zieldatei setzen, optional</p>
      "! @parameter iv_filename     | <p class="shorttext synchronized">Name der Datei ohne Extension</p>
      set_target_filename IMPORTING iv_filename TYPE char255,

      "!<p class="shorttext synchronized">Quelldaten (PDF) setzen</p>
      "! @parameter iv_raw     | <p class="shorttext synchronized">Binärdaten des PDF</p>
      "! @raising zcx_no_data_found | <p class="shorttext synchronized"> keine Daten vorhanden </p>
      set_source_data IMPORTING iv_raw TYPE xstring RAISING zcx_no_data_found,

      "!<p class="shorttext synchronized">Pfad für die Konvertierung festlegen</p>
      "! @parameter iv_path     | <p class="shorttext synchronized">Pfad für die Konvertierung mit slash am Ende</p>
      set_conversion_path IMPORTING iv_path TYPE char255,

      "!<p class="shorttext synchronized">Konvertierungsergebnis lesen</p>
      "! @parameter ev_raw     | <p class="shorttext synchronized">Binärdaten des erzeugten Bilds</p>
      get_conversion_result RETURNING VALUE(ev_raw) TYPE xstring,

      "!<p class="shorttext synchronized">Konvertierung starten</p>
      "! @parameter iv_keep_file     | <p class="shorttext synchronized">Zieldatei auf dem Server behalten, default ist löschen</p>
      "! @raising zcx_no_data_found | <p class="shorttext synchronized"> keine Quelldaten vorhanden </p>
      "! @raising cx_conversion_failed | <p class="shorttext synchronized"> Konvertierung fehlgeschlagen </p>
      "! @raising cx_authorization_missing | <p class="shorttext synchronized"> keine Rechte für Dateioperation </p>
      "! @raising cx_sy_file_io | <p class="shorttext synchronized"> Fehler beim lesen/schreiben der Dateien </p>
      convert IMPORTING iv_keep_file TYPE boolean DEFAULT abap_false RAISING zcx_no_data_found cx_conversion_failed cx_authorization_missing cx_sy_file_io.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS:
      "! <p class="shorttext synchronized">Quelldatei löschen</p>
      c_delete_source_file TYPE i VALUE 0,
      "! <p class="shorttext synchronized">Zieldatei löschen</p>
      c_delete_target_file TYPE i VALUE 1.

    METHODS:
      "!<p class="shorttext synchronized">Quelldatei auf App-Server erstellen</p>
      "! @raising cx_sy_file_io | <p class="shorttext synchronized"> Fehler beim schreiben der Datei </p>
      create_source_file RAISING cx_sy_file_io,

      "!<p class="shorttext synchronized">Konvertierung starten mittels SM69 Kommando</p>
      "! @raising cx_conversion_failed | <p class="shorttext synchronized"> Konvertierung fehlgeschlagen </p>
      call_conversion RAISING cx_conversion_failed cx_authorization_missing,

      "!<p class="shorttext synchronized">read_target_file</p>
      "! @raising cx_sy_file_io | <p class="shorttext synchronized"> Fehler beim lesen der Datei</p>
      read_target_file RAISING cx_sy_file_io,

      "!<p class="shorttext synchronized">Löschen der Datei auf dem App-Server</p>
      "! @parameter iv_file     | <p class="shorttext synchronized">Quell-, oder Zieldatei löschen? siehe C_DELETE_SOURCE_FILE</p>
      delete_file IMPORTING iv_file TYPE i.

    DATA:
      gv_target_format   TYPE i VALUE 0,
      gv_target_filename TYPE char255,
      gv_pdf_file        TYPE xstring,
      gv_target_file     TYPE xstring,
      gv_conversion_path TYPE char255 VALUE '/tmp/'.
ENDCLASS.



CLASS zcl_bc_pdf_converter IMPLEMENTATION.

  METHOD set_target_format.
    IF iv_format < c_convert_png OR iv_format > c_convert_jpg.
      RAISE EXCEPTION TYPE cx_invalid_format.
    ENDIF.

    gv_target_format = iv_format.

  ENDMETHOD.

  METHOD set_target_filename.
    gv_target_filename = iv_filename.
  ENDMETHOD.

  METHOD set_source_data.
    IF xstrlen( iv_raw ) = 0.
      RAISE EXCEPTION TYPE zcx_no_data_found.
    ENDIF.

    gv_pdf_file = iv_raw.
  ENDMETHOD.

  METHOD get_conversion_result.
    ev_raw = gv_target_file.
  ENDMETHOD.

  METHOD set_conversion_path.
    gv_conversion_path = iv_path.
  ENDMETHOD.

  METHOD convert.

    " keine Konvertierung ohne Daten
    IF xstrlen( gv_pdf_file ) = 0.
      RAISE EXCEPTION TYPE zcx_no_data_found.
    ENDIF.

    " eindeutiger Dateiname erstellen
    IF gv_target_filename IS INITIAL.
      gv_target_filename = cl_system_uuid=>create_uuid_c32_static( ).
    ENDIF.

    " Quelldaten auf Application Server ablegen
    me->create_source_file(  ).

    " Konvertieren der Daten auf App-Server
    me->call_conversion(  ).

    " lesen der konvertierten Daten vom App-Server
    me->read_target_file(  ).

    me->delete_file( c_delete_source_file ).
    " Löschen der konvertierten Daten
    IF iv_keep_file = abap_false.
      me->delete_file( c_delete_target_file ).
    ENDIF.

  ENDMETHOD.

  METHOD create_source_file.

    DATA(lv_file) = |{ gv_conversion_path }{ gv_target_filename }.pdf|.

    " Datei erstellen
    OPEN DATASET lv_file IN BINARY MODE FOR OUTPUT.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_file_io.
    ENDIF.

    " Daten übertragen
    TRANSFER gv_pdf_file TO lv_file.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_file_io.
    ENDIF.

    " Datei schließen
    CLOSE DATASET lv_file.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_file_io.
    ENDIF.

  ENDMETHOD.

  METHOD call_conversion.

    DATA: lv_additional_parameters TYPE btcxpgpar,
          lv_status                TYPE btcxpgstat,
          lt_result                TYPE STANDARD TABLE OF btcxpm.

    " Optionen für pdftoppm erstellen
    DATA(lv_option) = COND char5( WHEN gv_target_format = c_convert_tif THEN '-tif'
                        WHEN gv_target_format = c_convert_jpg THEN '-jpeg'
                        ELSE '-png').

    " Quelldatei + Pfad
    DATA(lv_source_file) = |{ gv_conversion_path }{ gv_target_filename }.pdf|.

    " Zieldatei + Pfad
    DATA(lv_destination_file) = |{ gv_conversion_path }{ gv_target_filename }|.

    lv_Additional_parameters = |{ lv_option } { lv_source_file } { lv_destination_file }|.

    " Aufruf der konvertierung über pdftoppm
    CALL FUNCTION 'SXPG_COMMAND_EXECUTE' DESTINATION 'NONE'
      EXPORTING
        commandname                = 'Z_PDFTOPPM'
*       OPERATINGSYSTEM            = SY-OPSYS
*       TARGETSYSTEM               = TARGETSYSTEM
        additional_parameters      = lv_ADDITIONAL_PARAMETERS
      IMPORTING
        status                     = lv_status
      TABLES
        exec_protocol              = lt_result
      EXCEPTIONS
        no_permission              = 01
        command_not_found          = 02
        parameters_too_long        = 03
        security_risk              = 04
        wrong_check_call_interface = 05
        program_start_error        = 06
        program_termination_error  = 07
        x_error                    = 08
        parameter_expected         = 09
        too_many_parameters        = 10
        illegal_command            = 11
        OTHERS                     = 12.

    CASE sy-subrc.
      WHEN 1.
        RAISE EXCEPTION TYPE cx_authorization_missing.
      WHEN 2.
        RAISE EXCEPTION TYPE cx_conversion_failed.
    ENDCASE.



  ENDMETHOD.

  METHOD read_target_file.

    DATA(lv_ext) = COND char4( WHEN gv_target_format = c_convert_tif THEN '.tif'
                               WHEN gv_target_format = c_convert_jpg THEN '.jpg'
                               ELSE '.png').

    DATA(lv_file) = |{ gv_conversion_path }{ gv_target_filename }-1{ lv_ext }|.

    OPEN DATASET lv_file IN BINARY MODE FOR INPUT.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_file_io.
    ENDIF.

    READ DATASET lv_file INTO gv_target_file.
    CLOSE DATASET lv_file.


  ENDMETHOD.

  METHOD delete_file.

    CASE iv_file.
      WHEN c_delete_source_file.
        DATA(lv_file) = |{ gv_conversion_path }{ gv_target_filename }.pdf|.
        DELETE DATASET lv_file.

      WHEN c_delete_target_file.
        DATA(lv_ext) = COND char4( WHEN gv_target_format = c_convert_tif THEN '.tif'
                              WHEN gv_target_format = c_convert_jpg THEN '.jpg'
                              ELSE '.png').

        lv_file = |{ gv_conversion_path }{ gv_target_filename }-1{ lv_ext }|.
        DELETE DATASET lv_file.

    ENDCASE.
  ENDMETHOD.

ENDCLASS.
