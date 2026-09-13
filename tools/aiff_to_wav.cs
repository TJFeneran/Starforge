using System;
using System.IO;
using System.Text;

public static class AiffToWav {
	public static void Main(string[] args) {
		string src = args.Length > 0 ? args[0] : @"assets\audio\player\85561__maj061785__running-up-stairs.aiff";
		string dst = Path.ChangeExtension(src, ".wav");
		byte[] data = File.ReadAllBytes(src);
		if (Encoding.ASCII.GetString(data, 0, 4) != "FORM")
			throw new Exception("Not AIFF FORM");
		int pos = 12;
		int channels = 0, sampleSize = 0, numSampleFrames = 0;
		double sampleRate = 0;
		int ssndOffset = -1, ssndSize = 0, ssndDataOffset = 0;
		while (pos + 8 <= data.Length) {
			string id = Encoding.ASCII.GetString(data, pos, 4);
			int size = ReadBE32(data, pos + 4);
			int chunkData = pos + 8;
			if (id == "COMM") {
				channels = ReadBE16(data, chunkData);
				numSampleFrames = ReadBE32(data, chunkData + 2);
				sampleSize = ReadBE16(data, chunkData + 6);
				sampleRate = ReadIEEE754Extended(data, chunkData + 8);
			} else if (id == "SSND") {
				int offset = ReadBE32(data, chunkData);
				ssndDataOffset = chunkData + 8 + offset;
				ssndSize = size - 8 - offset;
				ssndOffset = ssndDataOffset;
			}
			pos = chunkData + size + (size & 1);
		}
		if (ssndOffset < 0 || channels == 0)
			throw new Exception("Missing COMM/SSND");
		int bytesPerSample = sampleSize / 8;
		int frames = ssndSize / (bytesPerSample * channels);
		using (var fs = File.Create(dst))
		using (var bw = new BinaryWriter(fs)) {
			int dataBytes = frames * channels * 2; // write 16-bit
			bw.Write(Encoding.ASCII.GetBytes("RIFF"));
			bw.Write(36 + dataBytes);
			bw.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
			bw.Write(16);
			bw.Write((short)1);
			bw.Write((short)channels);
			bw.Write((int)sampleRate);
			bw.Write((int)sampleRate * channels * 2);
			bw.Write((short)(channels * 2));
			bw.Write((short)16);
			bw.Write(Encoding.ASCII.GetBytes("data"));
			bw.Write(dataBytes);
			for (int i = 0; i < frames * channels; i++) {
				int o = ssndOffset + i * bytesPerSample;
				short s;
				if (bytesPerSample == 2)
					s = (short)((data[o] << 8) | data[o + 1]);
				else if (bytesPerSample == 1)
					s = (short)((data[o] - 128) << 8);
				else if (bytesPerSample == 3)
					s = (short)((data[o] << 8) | data[o + 1]);
				else
					s = (short)((data[o] << 8) | data[o + 1]);
				bw.Write(s);
			}
		}
		Console.WriteLine("Wrote " + dst + " ch=" + channels + " rate=" + sampleRate + " frames=" + frames);
	}

	static int ReadBE16(byte[] d, int o) { return (d[o] << 8) | d[o + 1]; }
	static int ReadBE32(byte[] d, int o) { return (d[o] << 24) | (d[o + 1] << 16) | (d[o + 2] << 8) | d[o + 3]; }

	static double ReadIEEE754Extended(byte[] d, int o) {
		int exp = ((d[o] & 0x7F) << 8) | d[o + 1];
		ulong mant = 0;
		for (int i = 0; i < 8; i++) mant = (mant << 8) | d[o + 2 + i];
		if (exp == 0 && mant == 0) return 0;
		double sign = (d[o] & 0x80) != 0 ? -1.0 : 1.0;
		return sign * Math.Pow(2.0, exp - 16383) * (mant / Math.Pow(2.0, 63));
	}
}
