load("@hdl_rules//verilog:defs.bzl", "verilog_library")
load("@hdl_rules//jinja2:defs.bzl", "verilog_jinja2_render")

visibility("private")

DelayLineParamsInfo = provider(
    fields = {
        "params_file": "JSON file with parameters for delay line module",
    }
)

def _delay_line_params_impl(ctx):
    checked_params_file = None

    if ctx.file.params_file:
        if ctx.attr.params_json_string:
            fail("If parameters from files are used, you mustn't forward non-file parameters")
        checked_params_file = ctx.file.params_file
    elif ctx.attr.params_json_string:
        checked_params_file = ctx.actions.declare_file(ctx.label.name + "_checked.json")
        ctx.actions.write(
            output = checked_params_file,
            content = ctx.attr.params_json_string
        )
    else:
        fail("No parameters sources specified")

    verified_params_file = (
        ctx.outputs.out
        if ctx.outputs.out != None
        else ctx.actions.declare_file(ctx.label.name + ".json")
    )

    checker_args = ctx.actions.args()
    checker_args.add("--input", checked_params_file)
    checker_args.add("--output", verified_params_file)

    ctx.actions.run(
        executable = ctx.attr._checker_script[DefaultInfo].files_to_run,
        inputs = [checked_params_file],
        outputs = [verified_params_file],
        arguments = [checker_args],
        mnemonic = "CheckDelayLineParams",
    )

    return [
        DefaultInfo(files = depset([verified_params_file])),
        DelayLineParamsInfo(params_file = verified_params_file)
    ]

delay_line_params = rule(
    implementation = _delay_line_params_impl,
    attrs = {
        "params_json_string": attr.string(),
        "params_file": attr.label(
            allow_single_file = [".json"],
        ),
        "out": attr.output(),
        "_checker_script": attr.label(
            default = Label("//tools:params_checker"),
            executable = True,
            cfg = "exec",
        )
    },
)

_TEMPLATES = [
    Label("//src:cell.sv.j2"),
    Label("//src:top.sv.j2"),
]

def delay_line(
    name,
    params      = None,
    params_file = None,
    visibility  = None):

    if params != None and params_file != None:
        fail("Two sources of parameters are not allowed")

    if params == None and params_file == None:
        fail("One source of parameters must be specified")

    params_target = name + "_params"
    params_output_file = name + "/config/params.json"

    delay_line_params(
        name = params_target,
        params_json_string = json.encode(params) if params != None else "",
        params_file = params_file,
        out = params_output_file,
    )

    rendered_files = []

    for template in _TEMPLATES:
        if not template.name.endswith(".sv.j2"):
            fail("Expected .sv.j2 template file, but got %s" % template)

        template_name = template.name.removesuffix(".sv.j2")
        target_name   = name + "_" + template_name
        out_name      = name + "/src/" + template_name + ".sv"

        verilog_jinja2_render(
            name     = target_name,
            template = template,
            out      = out_name,
            params_file = ":" + params_target,
        )

        rendered_files.append(":" + target_name)

    verilog_library(
        name = name,
        deps = rendered_files,
        visibility = visibility
    )

