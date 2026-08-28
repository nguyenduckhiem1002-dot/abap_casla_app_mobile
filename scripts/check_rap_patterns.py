from pathlib import Path


def main() -> None:
    user_bdef = Path("serialized/zi_mob_user.bdef.asbdef").read_text(encoding="utf-8")
    if user_bdef.count("deep result [1] ZA_MOB_LoginResult") != 2:
        raise SystemExit("login/refresh phải dùng deep result ZA_MOB_LoginResult")

    pp_bdef = Path("serialized/zr_pp_opalloc.bdef.asbdef").read_text(encoding="utf-8")
    if pp_bdef.count("deep result [1] ZA_PP_HistResult") != 1:
        raise SystemExit("getWorkHistory phải dùng deep result ZA_PP_HistResult")

    md_bdef = Path("serialized/zi_md_congdoan.bdef.asbdef").read_text(encoding="utf-8")
    key_rule = "field ( mandatory : create, readonly : update ) MaCongDoan, ValidFrom;"
    if key_rule not in md_bdef:
        raise SystemExit(
            "MaCongDoan/ValidFrom phải dùng mandatory:create + readonly:update"
        )
    if "field ( mandatory ) MaCongDoan" in md_bdef:
        raise SystemExit(
            "Không được kết hợp mandatory với readonly:update cho MaCongDoan/ValidFrom"
        )

    pp_impl = Path("serialized/zbp_r_pp_opalloc.clas.locals_imp.abap").read_text(
        encoding="utf-8"
    )
    for method in (
        "initialAssign",
        "transfer",
        "recall",
        "confirm",
        "reverse",
        "correctConfirm",
    ):
        start = pp_impl.index(f"  METHOD {method}.")
        end = pp_impl.index("  ENDMETHOD.", start)
        block = pp_impl[start:end]
        if "<key>-%cid" in block:
            raise SystemExit(
                f"{method}: input của bound action không có component %cid; phải dùng %tky"
            )

    if "corrections-correction_qty" in pp_impl:
        raise SystemExit(
            "Aggregate một cột INTO @DATA(...) là scalar, không được dereference component"
        )

    for path in Path("serialized").glob("*.ddlx.asddlxs"):
        mde = path.read_text(encoding="utf-8")
        if "@UI.facet" not in mde:
            continue
        annotate = mde.find("annotate entity ")
        if annotate < 0:
            raise SystemExit(f"{path.name}: không tìm thấy annotate entity")
        opening_brace = mde.find("{", annotate)
        if opening_brace < 0:
            raise SystemExit(f"{path.name}: không tìm thấy block annotate")
        facet_pos = mde.find("@UI.facet")
        while facet_pos >= 0:
            if facet_pos < opening_brace:
                raise SystemExit(
                    f"{path.name}: @UI.facet phải nằm trong block annotate entity ... with {{ ... }}"
                )
            facet_pos = mde.find("@UI.facet", facet_pos + 1)


if __name__ == "__main__":
    main()
