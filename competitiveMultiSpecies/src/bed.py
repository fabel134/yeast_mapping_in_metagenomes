import numpy as np
import pandas as pd
import os
import argparse

def split_into_equal_bins(chrom, length, n_bins):
    """Divide un cromosoma corto in un numero prefissato di bin uguali."""
    base = length // n_bins
    remainder = length % n_bins

    bins = []
    start = 1

    for i in range(n_bins):
        end = start + base - 1
        if i < remainder:  # distribuisce il resto sui primi bin
            end += 1

        bins.append([chrom, start, end])
        start = end + 1

    return bins


def bed_multi_species(input_file, output_path, genome_name, bin_step):

    # --- Carica file ---
    df = pd.read_csv(input_file, sep=r"\s+", header=None, names=["chr", "length"])
    df["length"] = df["length"].astype(int)

    # --- Estrae specie mantenendo ordine del file ---
    df["species"] = df["chr"].apply(lambda x: x.split("_")[-1])

    species_order = []
    seen = set()
    for sp in df["species"]:
        if sp not in seen:
            species_order.append(sp)
            seen.add(sp)

    df["species"] = pd.Categorical(df["species"], categories=species_order, ordered=True)

    all_bed_rows = []

    # --- Cicla specie nel loro ordine originale ---
    for species in species_order:
        subdf = df[df["species"] == species]

        # Mantiene ordine cromosomi esattamente come nel file
        chroms_in_order = subdf["chr"].tolist()
        lengths_in_order = subdf["length"].tolist()

        # Determina lunghi e corti
        long_mask = subdf["length"] >= bin_step * 10
        long_chrs = subdf[long_mask]
        short_chrs = subdf[~long_mask]

        # Caso: specie senza cromosomi lunghi → tutti sono "corti"
        if long_chrs.empty:
            # prendi il cromosoma più lungo tra quelli corti
            longest_chr = subdf.iloc[subdf["length"].idxmax()]
            longest_len = longest_chr["length"]
        
            # almeno 20 bin
            n_bins = 20
        
            # nuova finestra calcolata dal cromosoma più lungo
            window = max(1, longest_len // n_bins)
        
            # binnaggio di tutti i cromosomi usando la nuova finestra
            for chrom, length in zip(chroms_in_order, lengths_in_order):
                for start in range(1, length + 1, window):
                    end = min(start + window - 1, length)
                    all_bed_rows.append([chrom, start, end])
        
            continue


        # Primo cromosoma lungo (in ordine di file)
        first_long_chr = long_chrs.iloc[0]
        ref_len = first_long_chr["length"]

        n_bins_ref = (ref_len + bin_step - 1) // bin_step

        # Applica la logica in ordine esatto
        for chrom, length in zip(chroms_in_order, lengths_in_order):

            if length >= bin_step * 10:
                # Cromosoma lungo → usa finestra standard
                for start in range(1, length + 1, bin_step):
                    end = min(start + bin_step - 1, length)
                    all_bed_rows.append([chrom, start, end])

            else:
                # Cromosoma corto → usa numero di bin del cromosoma lungo
                bins = split_into_equal_bins(chrom, length, n_bins_ref)
                all_bed_rows.extend(bins)

    # --- Output ---
    output_file = os.path.join(output_path, f"{genome_name}.bed")
    bed_df = pd.DataFrame(all_bed_rows, columns=["chrom", "start", "end"])
    bed_df.to_csv(output_file, sep="\t", header=False, index=False)


def main():
    parser = argparse.ArgumentParser(description="Generate genomic bins for multispecies chromosomes.")
    parser.add_argument("input_file", type=str, help="Path of the input multi-species .chrs.len file.")
    parser.add_argument("output_path", type=str, help="Output directory.")
    parser.add_argument("genome_name", type=str, help="Genome name prefix.")
    parser.add_argument("bin_step", type=int, help="Default bin size for long chromosomes.")

    args = parser.parse_args()

    bed_multi_species(
        input_file=args.input_file,
        output_path=args.output_path,
        genome_name=args.genome_name,
        bin_step=args.bin_step
    )


if __name__ == "__main__":
    main()
