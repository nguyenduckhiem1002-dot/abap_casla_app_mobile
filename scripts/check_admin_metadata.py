"""Static guardrails for the admin CDS metadata/service contract.

This check intentionally does not try to parse CDS. ADT/tenant activation remains
the authority for CDS syntax and annotation scope; the script catches regressions
where package moves silently drop a metadata extension or service provider.
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        raise AssertionError(f"Missing admin metadata artifact: {relative}")
    return path.read_text(encoding="utf-8")


def require(text: str, needle: str, source: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing {needle!r} in {source}")


def check_value_help_exposure(service: str, consumers: tuple[str, ...]) -> int:
    service_source = read(service)
    checked = 0
    for consumer in consumers:
        for provider in re.findall(
            r"valueHelpDefinition:\s*\[\{\s*entity:\s*\{\s*name:\s*'([^']+)'",
            read(consumer),
        ):
            require(service_source, f"expose {provider} ", service)
            checked += 1
    return checked


def check_abapgit_companion_metadata() -> tuple[int, int]:
    """Catch source/XML mismatches that abaplint cannot see during import."""
    ddl_checks = 0
    for source_path in (ROOT / "serialized").rglob("*.ddls.asddls"):
        xml_path = source_path.with_suffix(".xml")
        if not xml_path.is_file():
            continue
        source = source_path.read_text(encoding="utf-8-sig")
        xml = xml_path.read_text(encoding="utf-8-sig")
        entity_match = re.search(
            r"\bdefine\s+(?:root\s+)?view\s+entity\s+([A-Za-z0-9_/]+)",
            source,
            flags=re.IGNORECASE,
        )
        ddl_match = re.search(r"<DDLNAME>([^<]+)</DDLNAME>", xml)
        if entity_match and ddl_match:
            if entity_match.group(1).upper() != ddl_match.group(1).upper():
                raise AssertionError(
                    "CDS entity name does not match DDL source name: "
                    f"{source_path.relative_to(ROOT)} "
                    f"({entity_match.group(1)} != {ddl_match.group(1)})"
                )
            ddl_checks += 1

    test_include_checks = 0
    for test_path in (ROOT / "serialized").rglob("*.clas.testclasses.abap"):
        xml_name = test_path.name.replace(".clas.testclasses.abap", ".clas.xml")
        xml_path = test_path.with_name(xml_name)
        if not xml_path.is_file():
            raise AssertionError(
                f"Missing class XML for test include: {test_path.relative_to(ROOT)}"
            )
        require(
            xml_path.read_text(encoding="utf-8-sig"),
            "<WITH_UNIT_TESTS>X</WITH_UNIT_TESTS>",
            str(xml_path.relative_to(ROOT)),
        )
        test_include_checks += 1
    return ddl_checks, test_include_checks


def check_reserved_cds_element_names() -> None:
    for source_path in (ROOT / "serialized").rglob("*.ddls.asddls"):
        source = source_path.read_text(encoding="utf-8-sig")
        if re.search(r"\bas\s+TimeZone\b|^\s*TimeZone\s*[,;]", source, re.MULTILINE):
            raise AssertionError(
                "Reserved CDS element name TimeZone in "
                f"{source_path.relative_to(ROOT)}; use SAPTimeZone or ShiftTimeZone"
            )


def check_tenant_generated_artifacts() -> None:
    """G4BA/SUSH files are tenant-generated and unsupported by some abapGit clients."""
    generated = [
        path
        for path in (ROOT / "serialized").rglob("*")
        if path.is_file()
        and (path.name.endswith(".sco2.xml") or path.name.endswith(".sush.xml"))
    ]
    if generated:
        names = ", ".join(path.name for path in generated)
        raise AssertionError(
            "Tenant-generated G4BA/SUSH artifacts must not be committed: " + names
        )


def main() -> None:
    ddl_checks, test_include_checks = check_abapgit_companion_metadata()
    check_reserved_cds_element_names()
    check_tenant_generated_artifacts()
    abapgit_config = read(".abapgit.xml")
    for tenant_artifact in ("*.sco2.xml", "*.sush.xml"):
        require(
            abapgit_config,
            f"<item>{tenant_artifact}</item>",
            ".abapgit.xml tenant-specific OData exclusions",
        )
    metadata_files = [
        "serialized/zpk_xnsl_sm_backend_auth/zc_mob_user_adm.ddlx.asddlxs",
        "serialized/zpk_xnsl_sm_backend_role/zc_mob_role_adm.ddlx.asddlxs",
        "serialized/zpk_xnsl_sm_backend_role/zc_mob_func_adm.ddlx.asddlxs",
        "serialized/zpk_xnsl_sm_backend_role/zc_mob_rolfunc_adm.ddlx.asddlxs",
        "serialized/zpk_xnsl_sm_backend_role/zc_mob_rolwork_adm.ddlx.asddlxs",
        "serialized/zpk_xnsl_sm_backend_role/zc_mob_usrrol_adm.ddlx.asddlxs",
        "serialized/zpk_xnsl_sm_backend_wc/zc_mob_work_adm.ddlx.asddlxs",
        "serialized/zpk_xnsl_sm_backend_cd/zc_md_congdoan_adm.ddlx.asddlxs",
        "serialized/zc_pp_opalloc_adm.ddlx.asddlxs",
        "serialized/zc_pp_alloctxn_adm.ddlx.asddlxs",
        "serialized/zc_pp_shift_adm.ddlx.asddlxs",
    ]
    for relative in metadata_files:
        require(read(relative), "@Metadata.layer: #CORE", relative)

    work_metadata = read(
        "serialized/zpk_xnsl_sm_backend_wc/zc_mob_work_adm.ddlx.asddlxs"
    )
    require(work_metadata, "@EndUserText.label: 'Work ID'", "Work metadata")

    role_work_metadata = read(
        "serialized/zpk_xnsl_sm_backend_role/zc_mob_rolwork_adm.ddlx.asddlxs"
    )
    require(role_work_metadata, "@EndUserText.label: 'Work ID'", "Role-work metadata")

    function_metadata = read(
        "serialized/zpk_xnsl_sm_backend_role/zc_mob_func_adm.ddlx.asddlxs"
    )
    if "FuncId" in function_metadata:
        raise AssertionError("Function metadata contains the wrong FuncId path")

    service_consumers = {
        "serialized/zui_pp_alloc_adm.srvd.srvdsrv": (
            "serialized/zc_pp_opalloc_adm.ddls.asddls",
            "serialized/zc_pp_alloctxn_adm.ddls.asddls",
            "serialized/za_pp_correctconfirm.ddls.asddls",
        ),
        "serialized/zui_pp_shift_adm.srvd.srvdsrv": (
            "serialized/zc_pp_shift_adm.ddls.asddls",
        ),
        "serialized/zui_md_congdoan_adm.srvd.srvdsrv": (
            "serialized/zpk_xnsl_sm_backend_cd/zc_md_congdoan_adm.ddls.asddls",
        ),
        "serialized/zui_mob_user_adm.srvd.srvdsrv": (
            "serialized/zpk_xnsl_sm_backend_auth/zc_mob_user_adm.ddls.asddls",
            "serialized/zpk_xnsl_sm_backend_auth/za_mob_createuser.ddls.asddls",
            "serialized/zpk_xnsl_sm_backend_role/zc_mob_usrrol_adm.ddls.asddls",
        ),
        "serialized/zui_mob_rbac_adm.srvd.srvdsrv": (
            "serialized/zpk_xnsl_sm_backend_wc/zc_mob_work_adm.ddls.asddls",
            "serialized/zpk_xnsl_sm_backend_wc/zc_mob_rolwork_adm.ddls.asddls",
            "serialized/zpk_xnsl_sm_backend_role/zc_mob_rolfunc_adm.ddls.asddls",
        ),
    }
    exposure_checks = sum(
        check_value_help_exposure(service, consumers)
        for service, consumers in service_consumers.items()
    )

    op_admin = read("serialized/zc_pp_opalloc_adm.ddls.asddls")
    for field in ("MaCongDoan", "Plant", "WorkCenter", "UnitOfMeasure"):
        require(op_admin, field, "Operation Allocation admin CDS")

    shift_root = read("serialized/zr_pp_shift.ddls.asddls")
    require(shift_root, "define root view entity ZR_PP_Shift", "Shift root CDS")
    for marker in (
        "@Semantics.user.createdBy: true",
        "@Semantics.systemDateTime.createdAt: true",
        "@Semantics.user.lastChangedBy: true",
        "@Semantics.systemDateTime.lastChangedAt: true",
        "@Semantics.systemDateTime.localInstanceLastChangedAt: true",
    ):
        require(shift_root, marker, "Shift root audit semantics")

    shift_table = read("serialized/ztb_pp_shift.tabl.xml")
    for field in (
        "CREATED_BY",
        "CREATED_AT",
        "LAST_CHANGED_BY",
        "LAST_CHANGED_AT",
        "LOCAL_LAST_CHANGED_AT",
    ):
        require(shift_table, f"<FIELDNAME>{field}</FIELDNAME>", "Shift table audit fields")

    shift_draft_table = read("serialized/ztd_pp_shift.tabl.xml")
    require(
        shift_draft_table,
        "<PRECFIELD>SYCH_BDL_DRAFT_ADMIN_INC</PRECFIELD>",
        "Shift draft administration include",
    )
    shift_behavior = read("serialized/zr_pp_shift.bdef.asbdef")
    require(
        shift_behavior,
        "managed implementation in class zbp_r_pp_shift unique;",
        "Shift managed behavior",
    )
    for marker in (
        "with draft;",
        "draft table ztd_pp_shift",
        "total etag LastChangedAt",
        "etag master LocalLastChangedAt",
        "draft action Activate optimized;",
    ):
        require(shift_behavior, marker, "Shift managed draft behavior")
    shift_projection = read("serialized/zc_pp_shift_adm.ddls.asddls")
    require(
        shift_projection,
        "provider contract transactional_query",
        "Shift transactional projection",
    )
    shift_projection_behavior = read("serialized/zc_pp_shift_adm.bdef.asbdef")
    require(
        shift_projection_behavior,
        "use draft;",
        "Shift projection draft behavior",
    )
    require(
        shift_projection_behavior,
        "use create;",
        "Shift projection behavior",
    )

    correction_parameter = read("serialized/za_pp_correctconfirm.ddls.asddls")
    require(
        correction_parameter,
        "localElement: 'UnitOfMeasure', element: 'UnitOfMeasure', usage: #RESULT",
        "Correction transaction value help",
    )

    confirmation_value_help = read("serialized/zi_pp_confirm_txn_vh.ddls.asddls")
    for marker in (
        "left outer join ztb_pp_alloc_txn as reversal",
        "reversal.transaction_type = 'REVERSE'",
        "reversal.transaction_status = 'POSTED'",
        "reversal.transaction_uuid is null",
    ):
        require(text=confirmation_value_help, needle=marker, source="Confirmation value help")

    for relative in (
        "serialized/zi_pp_worker_hist_vh.ddls.asddls",
        "serialized/zi_md_congdoan_hist_vh.ddls.asddls",
        "serialized/zi_pp_confirm_txn_vh.ddls.asddls",
        "serialized/zpk_xnsl_sm_backend_wc/zi_mob_work_hist_vh.ddls.asddls",
    ):
        read(relative)

    print(
        f"Admin metadata guard passed: {len(metadata_files)} MDEs, "
        f"{exposure_checks} value-help exposures, 4 history providers, "
        f"{ddl_checks} DDL source names and {test_include_checks} test includes"
    )


if __name__ == "__main__":
    main()
