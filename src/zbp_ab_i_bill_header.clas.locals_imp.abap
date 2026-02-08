CLASS lhc_ZAB_I_Bill_Header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR BillHeader RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR BillHeader RESULT result.

    METHODS validateAmount FOR VALIDATE ON SAVE
      IMPORTING keys FOR BillHeader~validateAmount.

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





ENDCLASS.
