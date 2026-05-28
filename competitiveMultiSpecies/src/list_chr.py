import os
import argparse

def parse_args():
    parser = argparse.ArgumentParser(description="Estrai lista cromosomi da file .fa e crea file .chrs.list per ciascuna specie.")
    parser.add_argument("input_dir", help="Cartella contenente i file .fa")
    parser.add_argument("output_dir", help="Cartella in cui salvare i file .chrs.list")
    return parser.parse_args()

def extract_chromosomes(fasta_path):
    chroms = []
    with open(fasta_path, 'r') as f:
        for line in f:
            if line.startswith(">"):
                chrom = line[1:].strip()

                if chrom not in chroms:
                    chroms.append(chrom)
    return chroms

def main():
    args = parse_args()
    input_dir = args.input_dir
    output_dir = args.output_dir
    os.makedirs(output_dir, exist_ok=True)

    fasta_files = [f for f in os.listdir(input_dir) if f.endswith(".fa")]

    for fasta_file in fasta_files:
        fasta_path = os.path.join(input_dir, fasta_file)
        name_id = os.path.splitext(fasta_file)[0]
        chroms = extract_chromosomes(fasta_path)

        out_path = os.path.join(output_dir, f"{name_id}.chrs.list")
        with open(out_path, "w") as out_file:
            for chrom in chroms:
                out_file.write(chrom + "\n")

        print(f"Salvata lista cromosomi: {out_path}")

if __name__ == "__main__":
    main()

