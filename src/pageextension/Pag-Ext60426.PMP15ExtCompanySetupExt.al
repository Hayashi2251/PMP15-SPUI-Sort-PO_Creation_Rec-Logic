pageextension 60426 "PMP15 Ext. Company Setup Ext" extends "PMP07 Extended Company Setup"
{
    // VERSION PMP15

    // VERSION
    // Version List       Name
    // ============================================================================================================
    // PMP15             PMP SPUI - Sort-PO Creation & Recording (Logic)
    // 
    // PAGE EXTENSION
    // Date        Developer  Version List  Trigger                     Description
    // ============================================================================================================
    // 2025/09/26  SW         PMP15         -                          Create Page Extension
    // 

    #region Layout
    layout
    {
        addafter("Number Series")
        {
            group(Sortation)
            {
                Caption = 'Sortation';
                field("PMP15 Sort-Prod. Order Nos."; Rec."PMP15 Sort-Prod. Order Nos.")
                {
                    ApplicationArea = All;
                    Caption = 'Sortation Prod. Order Nos.';
                    ToolTip = 'Specifies the No. Series to be used when creating Sortation Production Orders. Select from the available No. Series.';
                }
                field("PMP15 Inspect-Prod. Order Nos."; Rec."PMP15 Inspect-Prod. Order Nos.")
                {
                    ApplicationArea = All;
                    Caption = 'Inspection Prod. Order Nos.';
                    ToolTip = 'Specifies the No. Series to be used when creating Inspection Production Orders. Select from the available No. Series.';
                }
                field("PMP15 SOR Output Jnl. Template"; Rec."PMP15 SOR Output Jnl. Template")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Output Journal Template';
                    ToolTip = 'Specifies the Item Journal Template to be used for Sortation Output. Only templates with Type = Output are available.';
                }
                field("PMP15 SOR Output Jnl. Batch"; Rec."PMP15 SOR Output Jnl. Batch")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Output Journal Batch';
                    ToolTip = 'Specifies the Item Journal Batch to be used for Sortation Output. The list is filtered by the selected SOR Output Journal Template.';
                }
                field("PMP15 SOR Consum.Jnl. Template"; Rec."PMP15 SOR Consum.Jnl. Template")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Consumption Journal Template';
                    ToolTip = 'Specifies the Item Journal Template to be used for Sortation Consumption. Only templates with Type = Consumption are available.';
                }
                field("PMP15 SOR Consum.Jnl. Batch"; Rec."PMP15 SOR Consum.Jnl. Batch")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Consumption Journal Batch';
                    ToolTip = 'Specifies the Item Journal Batch to be used for Sortation Consumption. The list is filtered by the selected SOR Consumption Journal Template.';
                }
                field("PMP15 SOR Item Owner Internal"; Rec."PMP15 SOR Item Owner Internal")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Item Owner Internal';
                    ToolTip = 'Specifies the default Item Owner for internal sortation transactions. Select from the Item Owner Internal list.';
                }
                field("PMP15 SOR Location Code"; Rec."PMP15 SOR Location Code")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Location Code';
                    ToolTip = 'Specifies the Location where sortation processes will be executed. Select from the Location list.';
                }
                field("PMP15SORItemReclass.Jnl.Tmpt."; Rec."PMP15SORItemReclass.Jnl.Tmpt.")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Item Reclass. Journal Template';
                    ToolTip = 'Specifies the Item Journal Template to be used for Sortation Item Reclassification. Only templates with Type = Transfer are available.';
                }
                field("PMP15SORItemReclass.Jnl.Batch"; Rec."PMP15SORItemReclass.Jnl.Batch")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Item Reclass. Journal Batch';
                    ToolTip = 'Specifies the Item Journal Batch to be used for Sortation Item Reclassification. The list is filtered by the selected SOR Item Reclass. Journal Template.';
                }
                field("PMP15 SOR Assembly Order Nos"; Rec."PMP15 SOR Assembly Order Nos")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Assembly Order Nos.';
                    ToolTip = 'Specifies the number series used for Assembly Orders in the Sortation process.';
                }
                field("PMP15 SOR Pstd-Asmbly Ord. Nos"; Rec."PMP15 SOR Pstd-Asmbly Ord. Nos")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Posted Assembly Order Nos.';
                    ToolTip = 'Specifies the number series used for posted Assembly Orders in the Sortation process.';
                }
                field("PMP15 SOR Inv. Shipment Nos"; Rec."PMP15 SOR Inv. Shipment Nos")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Inventory Shipment Nos.';
                    ToolTip = 'Specifies the number series used for Inventory Shipments in the Sortation process.';
                }
                field("PMP15 SOR Pstd-Inv. Shipment"; Rec."PMP15 SOR Pstd-Inv. Shipment")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Posted Inventory Shipment';
                    ToolTip = 'Specifies the number series used for posted Inventory Shipments in the Sortation process.';
                }
                field("PMP15 SOR Invt.Ship.Reason"; Rec."PMP15 SOR Invt.Ship.Reason")
                {
                    ApplicationArea = All;
                    Caption = 'SOR Invt. Shipment Reason Code';
                    ToolTip = 'Specifies the reason code used for Inventory Shipment transactions in the Sortation process.';
                }
            }
        }
    }
    #endregion Layout

    #region Actions
    actions { }
    #endregion Actions
}
