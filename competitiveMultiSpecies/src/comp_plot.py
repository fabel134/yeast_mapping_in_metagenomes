import os
import argparse
import pandas as pd
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
from matplotlib.backends.backend_pdf import PdfPages
import matplotlib.colors as mcolors
import matplotlib.cm as cm
import math

matplotlib.use("Agg")

# -----------------------------
# ARGOMENTI
# -----------------------------
def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("base_dir")
    parser.add_argument("strain")
    parser.add_argument("nameid")
    parser.add_argument("plotdir")
    parser.add_argument("chrom_list")   # file unico con TUTTI i cromosomi
    return parser.parse_args()

# -----------------------------
# UTILS
# -----------------------------
def read_chrom_list(path):
    with open(path) as f:
        return [x.strip() for x in f if x.strip()]

def natural_chr_order(chrs):
    """Ordina chr1, chr2, chr10 correttamente"""
    def keyfunc(c):
        return int(c.replace("chr", ""))
    return sorted(chrs, key=keyfunc)

def split_fields(df):
    df["chr"] = df["rname"].str.split("_", n=1).str[0]
    df["species"] = df["rname"].str.split("_", n=1).str[1]
    df["mid"] = (df["startpos"] + df["endpos"]) / 2
    return df

def plot_page(df, species_subset, chr_columns, pdf, cmap, norm):
    nrows = len(species_subset)
    ncols = len(chr_columns)

    fig, axs = plt.subplots(
        nrows, ncols,
        figsize=(3.3 * ncols, 2.8 * nrows),
        sharex=False, sharey=False
    )

    if nrows == 1:
        axs = np.array([axs])
    axs = np.atleast_2d(axs)

    # Titolo dei cromosomi solo una volta, in alto
    for j, chrom in enumerate(chr_columns):
        axs[0][j].set_title(chrom, fontsize=12)

    # Ciclo specie
    for i, sp in enumerate(species_subset):
        sp_df = df[df["species"] == sp]

        # Label specie a sinistra
        axs[i][0].annotate(
            sp,
            xy=(-0.2, 0.5),
            xycoords='axes fraction',
            ha='right',
            va='center',
            rotation=90,
            fontsize=9,
            fontweight='bold'
        )

        col_index = 0
        for chrom in chr_columns:
            sub = sp_df[sp_df["chr"] == chrom]
            if len(sub) > 0:
                ax = axs[i][col_index]

                if len(sub) > 1:
                    x = sub["mid"].values
                    y = sub["meandepth"].values
                    c = sub["perc_pos_covered"].values

                    points = np.array([x, y]).T.reshape(-1, 1, 2)
                    segments = np.concatenate([points[:-1], points[1:]], axis=1)

                    lc = LineCollection(segments, cmap=cmap, norm=norm)
                    lc.set_array(c[:-1])
                    lc.set_linewidth(1.0)
                    ax.add_collection(lc)

                    ax.set_xlim(x.min(), x.max())
                    ymax = np.mean(y[y > 0]) * 10 if np.any(y > 0) else 1
                    ax.set_ylim(0, ymax)
                else:
                    # singolo punto
                    yval = sub["meandepth"].values[0]
                    ax.plot([0, 1], [yval, yval], alpha=0)  # invisibile
                    ax.set_ylim(0, max(yval*1.2, 1))

                # Asse X: solo lunghezza finale del cromosoma
                ax.set_xticks([sub["endpos"].max()])
                ax.set_xticklabels([f"{int(sub['endpos'].max()):.2e}"], fontsize=9)
                ax.tick_params(axis='y', labelsize=8)

                col_index += 1

        # disattiva eventuali assi vuoti a destra
        for j in range(col_index, ncols):
            axs[i][j].axis("off")

    # Asse X comune
    fig.text(0.5, 0.06, "Binned genomes", ha="center", fontsize=12)

    # Asse Y comune
    fig.text(0.03, 0.5, "Average coverage", va="center", rotation="vertical", fontsize=12)

    # Legend
    sm = cm.ScalarMappable(cmap=cmap, norm=norm)
    sm.set_array([])
    cbar = fig.colorbar(sm, ax=axs, shrink=0.6, location='right')
    cbar.set_label("Percentage covered (%)")

    pdf.savefig(fig)
    plt.close(fig)

# -----------------------------
# MAIN
# -----------------------------
def main():
    args = parse_args()

    cov_path = os.path.join(args.base_dir, "cov", args.nameid, f"{args.strain}.{args.nameid}.binned.cov")
    if not os.path.exists(cov_path):
        print("File non trovato:", cov_path)
        return

    chrom_list_full = read_chrom_list(args.chrom_list)

    # specie → lista cromosomi e ordine specie come nel file
    species_to_chrs = {}
    species_order = []
    for c in chrom_list_full:
        chrom, sp = c.split("_", 1)
        species_to_chrs.setdefault(sp, []).append(chrom)
        if sp not in species_order:
            species_order.append(sp)

    # specie con più cromosomi
    max_species = max(species_to_chrs, key=lambda s: len(species_to_chrs[s]))
    chr_columns = natural_chr_order(species_to_chrs[max_species])

    print("Specie con più cromosomi:", max_species)
    print("Colonne globali:", chr_columns)

    # carica cov
    df = pd.read_csv(
        cov_path,
        sep="\t",
        header=None,
        names=[
            "rname","startpos","endpos","nreads","covbases",
            "perc_pos_covered","meandepth","meanbaseq","meanmapq","strain"
        ]
    )
    df["rname"] = df["rname"].astype(str)
    df = split_fields(df)
    df = df.sort_values(["species", "chr", "startpos"])

    out_pdf = os.path.join(args.plotdir, f"{args.strain}.ALL.pdf")
    os.makedirs(os.path.dirname(out_pdf), exist_ok=True)

    cmap = plt.colormaps["inferno"].reversed()
    norm = mcolors.Normalize(vmin=0, vmax=100)

    with PdfPages(out_pdf) as pdf:
        # 5 specie per pagina
        for i in range(0, len(species_order), 5):
            subset = species_order[i:i+5]
            plot_page(df, subset, chr_columns, pdf, cmap, norm)

    print("PDF generato:", out_pdf)

if __name__ == "__main__":
    main()
