page 60448 "PMP15 SOR Unpack Pkg. Card"
{
    // VERSION PMP15 

    // VERSION
    // Version List       Name
    // ============================================================================================================
    // PMP15              PMP SPUI - Sort-PO Creation & Recording (Logic)
    // 
    // PAGE
    // Date        Developer  Version List  Trigger                     Description
    // ============================================================================================================
    // 2026/01/06  SW         PMP15         -                           Create Page
    // 
    ApplicationArea = All;
    Caption = 'Sortation Unpack Package';
    DataCaptionFields = "No.", "Sorted Item No.", Type;
    PageType = Card;
    SourceTable = "PMP15 Sortation Unpack Package";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Caption = 'No.';
                    ToolTip = 'Specifies the value of the No. field.', Comment = '%';
                    trigger OnAssistEdit()
                    begin
                        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/22 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                        if Rec.AssistEdit(xRec) then
                            CurrPage.Update();
                        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/22 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    end;
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    Caption = 'Posting Date';
                    ToolTip = 'Specifies the value of the Posting Date field.', Comment = '%';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    ToolTip = 'Specifies the value of the Status field.', Comment = '%';
                    Visible = false;
                    Editable = false;
                }
                field("Type"; Rec."Type")
                {
                    ApplicationArea = All;
                    Caption = 'Type';
                    ToolTip = 'Specifies the value of the Type field.', Comment = '%';
                }
                field("Sorted Item No."; Rec."Sorted Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Item No.';
                    ToolTip = 'Specifies the value of the Sorted Item No. field.', Comment = '%';
                }
                field("Sorted Variant Code"; Rec."Sorted Variant Code")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Variant Code';
                    ToolTip = 'Specifies the value of the Sorted Variant Code field.', Comment = '%';
                }
                field("Sorted Package No."; Rec."Sorted Package No.")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Package No.';
                    ToolTip = 'Specifies the value of the Sorted Package No. field.', Comment = '%';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Caption = 'Location Code';
                    ToolTip = 'Specifies the value of the Location Code field.', Comment = '%';
                    Editable = false;
                }
                field("Bin Code"; Rec."Bin Code")
                {
                    ApplicationArea = All;
                    Caption = 'Bin Code';
                    ToolTip = 'Specifies the value of the Bin Code field.', Comment = '%';
                    Editable = false;
                }
                field("Total Current Quantity"; Rec."Total Current Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Total Current Quantity';
                    ToolTip = 'Specifies the value of the Total Current Quantity field.', Comment = '%';
                    Editable = false;
                }
                field("Total New Quantity"; Rec."Total New Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Total New Quantity';
                    ToolTip = 'Specifies the value of the Total New Quantity field.', Comment = '%';
                    Editable = false;
                }
                field("Sum New Quantity"; Rec."Sum New Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Sum New Quantity';
                    ToolTip = 'Specifies the value of the Sum New Quantity field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field("No. of Printed"; Rec."No. of Printed")
                {
                    ApplicationArea = All;
                    Caption = 'No. of Printed';
                    ToolTip = 'Specifies the value of the No. of Printed field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field(IsPosted; Rec.IsPosted)
                {
                    ApplicationArea = All;
                    Caption = 'Is Posted ?';
                    ToolTip = 'Specifies the value of the is posted flag field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }

                #region BUSINESS CENTRAL (TIMESTAMP) SYSTEM FIELD
                field(SystemCreatedAt; Rec.SystemCreatedAt)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Specifies the value of the SystemCreatedAt field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field(SystemCreatedBy; Rec.SystemCreatedBy)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Specifies the value of the SystemCreatedBy field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field(SystemId; Rec.SystemId)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Specifies the value of the SystemId field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field(SystemModifiedAt; Rec.SystemModifiedAt)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Specifies the value of the SystemModifiedAt field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field(SystemModifiedBy; Rec.SystemModifiedBy)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Specifies the value of the SystemModifiedBy field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                #endregion BUSINESS CENTRAL (TIMESTAMP) SYSTEM FIELD
            }
            // Current Sortation Detail Result
            part(CurrDetResSORLine; "PMP15 SOR Unpack Curr-Det. Res")
            {
                ApplicationArea = All;
                SubPageLink = "Document No." = field("No.");
                UpdatePropagation = Both;
                Visible = (Rec.Type = Rec.Type::Reclassification) OR (Rec.Type = Rec.Type::Unpack);
            }
            // New Sortation Detail Result
            part(NewDetResSORLine; "PMP15 SOR Unpack New-Det. Res")
            {
                ApplicationArea = All;
                SubPageLink = "Document No." = field("No.");
                UpdatePropagation = Both;
                Visible = Rec.Type = Rec.Type::Unpack;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Generate)
            {
                ApplicationArea = All;
                Caption = 'Generate';
                Image = CreateDocument;
                trigger OnAction()
                begin
                    SortProdOrdMgmt.GenerateSORUnpackPackageLines(Rec);
                end;
            }
            action(Post)
            {
                ApplicationArea = All;
                Caption = 'Post';
                Image = Post;
                trigger OnAction()
                begin
                    SortProdOrdMgmt.PostSORUnpackPackage(Rec);
                end;
            }
        }

        #region PROMOTED ACTIONS
        area(Promoted)
        {
            actionref(Generate_Promoted; Generate) { }
            actionref(Post_Promoted; Post) { }
        }
        #endregion PROMOTED ACTIONS
    }

    trigger OnOpenPage()
    begin
        ExtCompanySetup.Get();
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Unpack Package Nos."));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Output Jnl. Template"));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Output Jnl. Batch"));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Consum.Jnl. Template"));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Consum.Jnl. Batch"));
    end;

    protected var
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        NoSeriesMgmt: Codeunit "No. Series";
        PMPAppLogicMgmt: Codeunit "PMP02 App Logic Management";
        SortProdOrdMgmt: Codeunit "PMP15 Sortation PO Mgmt";

}
