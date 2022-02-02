using Loan
using Documenter

DocMeta.setdocmeta!(Loan, :DocTestSetup, :(using Loan); recursive=true)

makedocs(;
    modules=[Loan],
    authors="Gustavo H T Cardoso <ghtcardoso@icloud.com> and contributors",
    repo="https://github.com/gustavohtc/Loan.jl/blob/{commit}{path}#{line}",
    sitename="Loan.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://gustavohtc.github.io/Loan.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/gustavohtc/Loan.jl",
)
