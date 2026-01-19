page 60407 "PMP15 Sub Merk 3"
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
    // 2025/09/12  SW         PMP15         -                           Create Page
    // 
    ApplicationArea = All;
    Caption = 'Sub Merk 3';
    PageType = List;
    SourceTable = "PMP15 Sub Merk";
    SourceTableView = where(Type = const("Sub Merk 3"));
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Tobacco Type"; Rec."Tobacco Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Tobacco Type field.', Comment = '%';
                }
                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Code field.', Comment = '%';
                    trigger OnValidate()
                    var
                        SubMerkRec2: Record "PMP15 Sub Merk";
                        SubMerkRec3: Record "PMP15 Sub Merk";
                    begin
                        // PERFORM UNIQUE VALIDATION HERE
                        CheckDuplicateSubMerk3(Rec, xRec);
                    end;
                }
                field("Sub Merk 2 Code"; Rec."Sub Merk 2 Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Submerk 2 field.', Comment = '%';
                    trigger OnValidate()
                    var
                        SubMerkRec2: Record "PMP15 Sub Merk";
                        SubMerkRec3: Record "PMP15 Sub Merk";
                    begin
                        // PERFORM UNIQUE VALIDATION HERE
                        CheckDuplicateSubMerk3(Rec, xRec);
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        SubMerkRec2: Record "PMP15 Sub Merk";
                        SubMerkRec3: Record "PMP15 Sub Merk";
                    begin
                        SubMerkRec2.SetRange(Type, SubMerkRec2.Type::"Sub Merk 2");
                        SubMerkRec2.SetRange("Tobacco Type", Rec."Tobacco Type");
                        if Page.RunModal(Page::"PMP15 Sub Merk 2", SubMerkRec2) = Action::LookupOK then begin
                            Rec."Sub Merk 2 Code" := SubMerkRec2.Code;

                            // PERFORM UNIQUE VALIDATION HERE
                            CheckDuplicateSubMerk3(Rec, xRec);
                        end;
                    end;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Description field.', Comment = '%';
                }
                field("Item Owner Internal"; Rec."Item Owner Internal")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Item Owner Internal field.', Comment = '%';
                }
                field(Group; Rec.Group)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Item Owner Internal field.', Comment = '%';
                }
                field(Ranking; Rec.Ranking)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Item Owner Internal field.', Comment = '%';
                }
            }
        }
    }

    /// <summary>Validates and prevents <b>duplicate Sub Merk 3</b> entries by checking for existing records with matching Tobacco Type, Code, and Sub Merk 2 Code.</summary>
    /// <remarks>
    /// This procedure performs a duplicate check specifically for Sub Merk 3 records within the Sub Merk table. It searches for any existing record that matches the combination of Type (fixed as "Sub Merk 3"), Tobacco Type, Code, and Sub Merk 2 Code from the provided record. If a duplicate is found, it restores the original Sub Merk 2 Code value and raises an error message that identifies the conflicting Tobacco Type, Sub Merk 2 Code, and Code values to help users resolve the duplication.
    /// </remarks>
    /// <param name="SMRec">The new or modified Sub Merk record to check for duplicates (passed by reference).</param>
    /// <param name="xSMRec">The original Sub Merk record containing previous field values before modification.</param>
    procedure CheckDuplicateSubMerk3(var SMRec: Record "PMP15 Sub Merk"; xSMRec: Record "PMP15 Sub Merk")
    var
        SubMerkRec3: Record "PMP15 Sub Merk";
    begin
        SubMerkRec3.SetRange(Type, SubMerkRec3.Type::"Sub Merk 3");
        SubMerkRec3.SetRange("Tobacco Type", SMRec."Tobacco Type");
        SubMerkRec3.SetRange(Code, SMRec.Code);
        SubMerkRec3.SetRange("Sub Merk 2 Code", SMRec."Sub Merk 2 Code");
        if SubMerkRec3.Count > 0 then begin
            SMRec."Sub Merk 2 Code" := xSMRec."Sub Merk 2 Code";
            SubMerkRec3.FindFirst();
            Error('There is a duplicate Sub Merk 3 with the Tobacco Type (%1) and the Sub Merk 2 Code (%2) with the Code of %3', SMRec."Tobacco Type", SubMerkRec3."Sub Merk 2 Code", SubMerkRec3.Code);
        end;
    end;
}
