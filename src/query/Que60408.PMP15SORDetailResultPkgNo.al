query 60408 "PMP15 SOR-Detail Result Pkg-No"
{
    // version PMP15 

    // List Modification
    // Version List       Name
    // =============================================================================================================
    // PMP15              PMP SPUI - Sort-PO Creation & Recording (Logic)

    // QUERY
    // Date        Developer  Version List  Description
    // =============================================================================================================
    // 2025/10/31  SW         PMP15         Create Query

    Caption = 'PMP15 SOR-Detail Result Pkg-No';
    QueryType = Normal;

    elements
    {
        dataitem(PackageNoInformation; "Package No. Information")
        {
            column(PNOI_ItemNo; "Item No.") { Caption = 'PNOI Item No.'; }
            column(PNOI_VariantCode; "Variant Code") { Caption = 'PNOI Var. Code'; }
            column(PNOI_PackageNo; "Package No.") { Caption = 'PNOI Pkg No.'; }
            column(PNOI_CountryRegionCode; "Country/Region Code") { Caption = 'PNOI Country'; }
            column(PNOI_Description; Description) { Caption = 'PNOI Description'; }
            column(PNOI_Blocked; Blocked) { Caption = 'PNOI Blocked'; }
            dataitem(PMP15_Sortation_Detail_Quality; "PMP15 Sortation Detail Quality")
            {
                DataItemLink = "Item No." = PackageNoInformation."Item No.", "Variant Code" = PackageNoInformation."Variant Code", "Package No." = PackageNoInformation."Package No.";
                column(SDR_ItemNo; "Item No.") { Caption = 'SDR Item No.'; }
                column(SDR_VariantCode; "Variant Code") { Caption = 'SDR Var. Code'; }
                column(SDR_PackageNo; "Package No.") { Caption = 'SDR Pkg No.'; }
                column(SDR_LotNo; "Lot No.") { Caption = 'SDR Lot No.'; }
                column(SDR_SubMerk1; "Sub Merk 1") { Caption = 'SDR Submerk 1'; }
                column(SDR_SubMerk2; "Sub Merk 2") { Caption = 'SDR Submerk 2'; }
                column(SDR_SubMerk3; "Sub Merk 3") { Caption = 'SDR Submerk 3'; }
                column(SDR_SubMerk4; "Sub Merk 4") { Caption = 'SDR Submerk 4'; }
                column(SDR_SubMerk5; "Sub Merk 5") { Caption = 'SDR Submerk 5'; }
                column(SDR_LR; "L/R") { Caption = 'SDR L/R'; }
                column(SDR_Quantity; Quantity) { Caption = 'SDR Qty.'; }
                column(SDR_UnitofMeasureCode; "Unit of Measure Code") { Caption = 'SDR UoM'; }
                column(SDR_Rework; Rework) { Caption = 'SDR Rework'; }
                column(SDR_TobaccoType; "Tobacco Type") { Caption = 'SDR Tbco. Type'; }
                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                #region REMOVED
                // dataitem(Sub_Merk_2; "PMP15 Sub Merk 2")
                // {
                //     DataItemLink = "Code" = PMP15_Sortation_Detail_Quality."Sub Merk 2";
                //     column(SM2_Description; Description) { Caption = 'SM2 Desc.'; }
                //     column(SM2_Group; Group) { Caption = 'SM2 Group'; }
                //     column(SM2_Ranking; Ranking) { Caption = 'SM2 Rank'; }
                //     dataitem(Sub_Merk_3; "PMP15 Sub Merk 3")
                //     {
                //         DataItemLink = "Code" = PMP15_Sortation_Detail_Quality."Sub Merk 3";
                //         column(SM3_Description; Description) { Caption = 'SM3 Desc.'; }
                //         column(SM3_Group; Group) { Caption = 'SM3 Group'; }
                //         column(SM3_Ranking; Ranking) { Caption = 'SM3 Rank'; }
                //     }
                // }
                #endregion REMOVED
                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
            }
        }
    }

    trigger OnBeforeOpen()
    begin

    end;
}
