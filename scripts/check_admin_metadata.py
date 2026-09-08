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


def main() -> None:
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
        f"{exposure_checks} value-help exposures and 4 history providers"
    )


if __name__ == "__main__":
    main()
