CLASS lhc_items DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calculateNetAmount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR items~calculateNetAmount.

    METHODS setDefaultCurrency FOR DETERMINE ON MODIFY
      IMPORTING keys FOR items~setDefaultCurrency.

ENDCLASS.

CLASS lhc_items IMPLEMENTATION.

  METHOD calculateNetAmount.
    "Read header keys
    READ ENTITIES OF zab_i_bill_header IN LOCAL MODE
      ENTITY BillHeader
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_header).

    LOOP AT lt_header ASSIGNING FIELD-SYMBOL(<ls_header>).

      "Read all items for this header (draft + active)
      READ ENTITIES OF zab_i_bill_header IN LOCAL MODE
        ENTITY BillHeader BY \_Item
        FIELDS ( ItemAmount )
        WITH VALUE #( ( %tky = <ls_header>-%tky ) )
        RESULT DATA(lt_items).

      DATA(lv_total) = CONV zab_bill_header-net_amount( 0 ).

      LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
        lv_total += <ls_item>-ItemAmount.
      ENDLOOP.

      " Update the header buffer with the new total
      MODIFY ENTITIES OF zab_i_bill_header IN LOCAL MODE
        ENTITY BillHeader
        UPDATE FIELDS ( NetAmount )
        WITH VALUE #( ( %tky = <ls_header>-%tky NetAmount = lv_total ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD setDefaultCurrency.
    " 1. Read the items to see if they have currency
    READ ENTITIES OF ZAB_I_Bill_Header IN LOCAL MODE
      ENTITY items
      FIELDS ( Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    DELETE lt_items WHERE Currency IS NOT INITIAL.
    CHECK lt_items IS NOT INITIAL.

    " 2. Set 'INR' as default for the new items
    MODIFY ENTITIES OF ZAB_I_Bill_Header IN LOCAL MODE
      ENTITY items
      UPDATE FIELDS ( Currency )
      WITH VALUE #( FOR item IN lt_items (
                      %tky     = item-%tky
                      Currency = 'INR' ) ).
  ENDMETHOD.


ENDCLASS.

CLASS lhc_ZAB_I_Bill_Header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR BillHeader RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR BillHeader RESULT result.

    METHODS validateAmount FOR VALIDATE ON SAVE
      IMPORTING keys FOR BillHeader~validateAmount.

    METHODS setBillDate FOR DETERMINE ON MODIFY
      IMPORTING keys FOR BillHeader~setBillDate.
    METHODS setDefaultCurrency FOR DETERMINE ON MODIFY
      IMPORTING keys FOR BillHeader~setDefaultCurrency.

    METHODS earlynumbering_cba_Item FOR NUMBERING
      IMPORTING entities FOR CREATE BillHeader\_Item.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE BillHeader.

ENDCLASS.

CLASS lhc_ZAB_I_Bill_Header IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD validateAmount.
    READ ENTITIES OF ZAB_I_Bill_Header IN LOCAL MODE
        ENTITY BillHeader
        FIELDS ( NetAmount BillDate ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_billdoc).

    LOOP AT lt_billdoc INTO DATA(ls_billdoc).
      IF ls_billdoc-NetAmount IS INITIAL OR ls_billdoc-NetAmount < 1000.
        APPEND VALUE #( %tky = ls_billdoc-%tky ) TO failed-billheader.
        APPEND VALUE #( %tky = ls_billdoc-%tky
                        %element-NetAmount = if_abap_behv=>mk-on
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text = 'Net Amount cannot be less than 1000' )
                       ) TO reported-billheader.
      ENDIF.

      DATA(lv_todayDate) = cl_abap_context_info=>get_system_date( ).
      IF ls_billdoc-BillDate IS INITIAL OR ls_billdoc-BillDate > lv_todayDate.
        APPEND VALUE #( %tky = ls_billdoc-%tky ) TO failed-billheader.
        APPEND VALUE #( %tky = ls_billdoc-%tky
                        %element-billdate = if_abap_behv=>mk-on
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text = 'Future Date Cannot be Created' )
                       ) TO reported-billheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    DATA: lv_max_active TYPE n LENGTH 10,
          lv_max_draft  TYPE n LENGTH 10,
          lv_next_id    TYPE n LENGTH 10.

    "Step 1: get max from active table
    SELECT MAX( bill_id )
      FROM zab_bill_header
      INTO @lv_max_active.

    "Step 2: get max from draft table
    SELECT MAX( billid )
      FROM zab_d_bill_head
      INTO @lv_max_draft.

    "Step 3: determine overall max
    lv_next_id = lv_max_active.

    IF lv_max_draft > lv_next_id.
      lv_next_id = lv_max_draft.
    ENDIF.

    "Step 4: if no records at all
    IF lv_next_id IS INITIAL.
      lv_next_id = '0000000001'.
    ELSE.
      lv_next_id += 1.
    ENDIF.

    LOOP AT entities INTO DATA(ls_ent).
      " If BillId already assigned → map as is
      IF ls_ent-BillId IS NOT INITIAL.
        APPEND VALUE #(
            %cid      = ls_ent-%cid
            %is_draft = ls_ent-%is_draft
            BillId    = ls_ent-BillId
          )
          TO mapped-billheader.
        CONTINUE.
      ENDIF.
      " 3. Map the new ID to the current entity
      APPEND VALUE #( %cid      = ls_ent-%cid
                      %is_draft = ls_ent-%is_draft
                      billid   = lv_next_id ) TO mapped-billheader.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_cba_Item.

    DATA: lv_max_item TYPE zab_bill_item-item_no.

    "Step 1: read existing items (active + draft)
    READ ENTITIES OF ZAB_I_Bill_Header IN LOCAL MODE
      ENTITY BillHeader BY \_Item
      FROM CORRESPONDING #( entities )
      LINK DATA(existing_items).

    "Step 2: group by header
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<header_group>)
         GROUP BY <header_group>-BillId.

      CLEAR lv_max_item.

      "Step 3: find max existing item
      LOOP AT existing_items INTO DATA(ls_existing).
        IF ls_existing-target-BillId = <header_group>-BillId
           AND lv_max_item < ls_existing-target-ItemNo.

          lv_max_item = ls_existing-target-ItemNo.
        ENDIF.
      ENDLOOP.

      "Step 4: consider items already in request
      LOOP AT entities INTO DATA(ls_entity)
           WHERE BillId = <header_group>-BillId.

        LOOP AT ls_entity-%target INTO DATA(ls_target).
          IF lv_max_item < ls_target-ItemNo.
            lv_max_item = ls_target-ItemNo.
          ENDIF.
        ENDLOOP.

      ENDLOOP.

      "Step 5: assign numbers
      LOOP AT entities ASSIGNING FIELD-SYMBOL(<header>)
           WHERE BillId = <header_group>-BillId.

        LOOP AT <header>-%target ASSIGNING FIELD-SYMBOL(<item>).

          APPEND CORRESPONDING #( <item> )
            TO mapped-items
            ASSIGNING FIELD-SYMBOL(<mapped_item>).

          IF <mapped_item>-ItemNo IS INITIAL.
            lv_max_item += 10.
            <mapped_item>-ItemNo = lv_max_item.
          ENDIF.

        ENDLOOP.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

  METHOD setBillDate.
    "Read current data (draft or active)
    READ ENTITIES OF zab_i_bill_header IN LOCAL MODE
      ENTITY BillHeader
      FIELDS ( BillDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_bill).

    LOOP AT lt_bill ASSIGNING FIELD-SYMBOL(<ls_bill>).

      "Idempotent logic (VERY IMPORTANT)
      IF <ls_bill>-BillDate IS INITIAL.
        <ls_bill>-BillDate = cl_abap_context_info=>get_system_date( ).
      ENDIF.
    ENDLOOP.

    "Update derived field
    MODIFY ENTITIES OF zab_i_bill_header IN LOCAL MODE
      ENTITY BillHeader
      UPDATE FIELDS ( BillDate )
      WITH VALUE #(
        FOR bill IN lt_bill
        ( %tky     = bill-%tky
          BillDate = bill-BillDate
          Currency = 'INR' )
      ).
  ENDMETHOD.

  METHOD setDefaultCurrency.
    READ ENTITIES OF ZAB_I_Bill_Header IN LOCAL MODE
      ENTITY BillHeader
      FIELDS ( Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    DELETE lt_headers WHERE Currency IS NOT INITIAL.
    CHECK lt_headers IS NOT INITIAL.

    MODIFY ENTITIES OF ZAB_I_Bill_Header IN LOCAL MODE
      ENTITY BillHeader
      UPDATE FIELDS ( Currency )
      WITH VALUE #( FOR header IN lt_headers (
                      %tky     = header-%tky
                      Currency = 'INR' ) ).
  ENDMETHOD.


ENDCLASS.
