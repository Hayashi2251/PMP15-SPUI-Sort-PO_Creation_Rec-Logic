tableextension 60499 "SOR Inspect Package Ext" extends "PMP15 SOR Inspection Pkg Headr"
{
    fields
    {
        field(60400; "Total Inspection Line"; Integer)
        {
            Caption = 'Total Inspection Line';
            FieldClass = FlowField;
            CalcFormula = count("PMP15 SOR Inspection Pkg. Line" WHERE("Document No." = FIELD("No.")));
        }
        field(60401; "Has Rejected Line"; Boolean)
        {
            Caption = 'Has Rejected Line';
            FieldClass = FlowField;
            CalcFormula = Exist("PMP15 SOR Inspection Pkg. Line" WHERE("Document No." = FIELD("No."), Result = const(Rejected)));
        }
        field(60402; "Total Rejected Line"; Integer)
        {
            Caption = 'Total Rejected Line';
            FieldClass = FlowField;
            CalcFormula = count("PMP15 SOR Inspection Pkg. Line" WHERE("Document No." = FIELD("No."), Result = const(Rejected)));
        }
        field(60403; "Total Rework Line"; Integer)
        {
            Caption = 'Total Rework Line';
            FieldClass = FlowField;
            CalcFormula = count("PMP15 SOR Inspection Pkg. Line" WHERE("Document No." = FIELD("No."), Result = const(Rework)));
        }
        field(60404; "Total Hold Line"; Integer)
        {
            Caption = 'Total Hold Line';
            FieldClass = FlowField;
            CalcFormula = count("PMP15 SOR Inspection Pkg. Line" WHERE("Document No." = FIELD("No."), Result = const(Hold)));
        }
    }
}
