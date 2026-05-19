const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

const AI_SCRIPT_PATH = path.join(__dirname, "..", "ai", "analyze_food_image.py");
const DEFAULT_TIMEOUT_MS = 120000;
const PROJECT_VENV_PYTHON = path.join(__dirname, "..", "..", ".venv", "Scripts", "python.exe");

const tryParseJson = (value) => {
	if (!value) {
		return null;
	}

	const trimmed = value.trim();
	if (!trimmed) {
		return null;
	}

	try {
		return JSON.parse(trimmed);
	} catch (error) {
		const firstBrace = trimmed.indexOf("{");
		const lastBrace = trimmed.lastIndexOf("}");

		if (firstBrace >= 0 && lastBrace > firstBrace) {
			try {
				return JSON.parse(trimmed.slice(firstBrace, lastBrace + 1));
			} catch (_innerError) {
				return null;
			}
		}

		return null;
	}
};

const getPythonCommands = () => {
	return [...new Set([
		process.env.AI_PYTHON_COMMAND,
		fs.existsSync(PROJECT_VENV_PYTHON) ? PROJECT_VENV_PYTHON : null,
		"python",
		"py",
	].filter(Boolean))];
};

const runPythonScript = (scriptPath, imagePath) => {
	const timeoutMs = Number(process.env.AI_PYTHON_TIMEOUT_MS || DEFAULT_TIMEOUT_MS);

	return new Promise((resolve, reject) => {
		const commands = getPythonCommands();
		let index = 0;

		const tryNext = (lastError) => {
			if (index >= commands.length) {
				reject(lastError || new Error("No Python interpreter available"));
				return;
			}

			const command = commands[index++];
			const child = spawn(command, [scriptPath, imagePath], {
				cwd: path.join(__dirname, ".."),
				windowsHide: true,
			});

			let stdout = "";
			let stderr = "";
			let finished = false;

			const timeoutId = setTimeout(() => {
				if (finished) {
					return;
				}

				finished = true;
				child.kill();
				tryNext(new Error(`[AI] python timeout after ${timeoutMs}ms`));
			}, timeoutMs);

			child.stdout.on("data", (chunk) => {
				stdout += chunk.toString();
			});

			child.stderr.on("data", (chunk) => {
				stderr += chunk.toString();
			});

			child.on("error", (error) => {
				if (finished) {
					return;
				}

				finished = true;
				clearTimeout(timeoutId);
				tryNext(error);
			});

			child.on("close", (code) => {
				if (finished) {
					return;
				}

				finished = true;
				clearTimeout(timeoutId);

				const parsed = tryParseJson(stdout);
				if (parsed) {
					resolve({ parsed, stdout, stderr, code, command });
					return;
				}

				if (code === 0) {
					reject(
						new Error(
							`[AI] ${command} exited without valid JSON. stdout=${stdout || "<empty>"} stderr=${stderr || "<empty>"}`
						)
					);
					return;
				}

				tryNext(
					new Error(
						`[AI] ${command} exited with code ${code}. stdout=${stdout || "<empty>"} stderr=${stderr || "<empty>"}`
					)
				);
			});
		};

		tryNext();
	});
};

const safeUnlink = async (filePath) => {
	if (!filePath) {
		return;
	}

	try {
		await fs.promises.unlink(filePath);
	} catch (error) {
		if (error.code !== "ENOENT") {
			console.error("[AI] Failed to delete temp image:", error.message);
		}
	}
};

const analyzeImageAI = async (req, res) => {
	const uploadedFile = req.file;

	if (!uploadedFile) {
		return res.status(400).json({
			success: false,
			message: "Image file is required",
		});
	}

	try {
		const { parsed, stderr, code, command } = await runPythonScript(AI_SCRIPT_PATH, uploadedFile.path);

		if (stderr) {
			console.log("[AI] python stderr:", stderr.trim());
		}

		console.log(`[AI] python exited: ${command} (code ${code})`);

		if (parsed && parsed.success === false) {
			return res.status(502).json({
				success: false,
				message: parsed.message || "AI analysis failed",
				detail: parsed,
			});
		}

		return res.status(200).json({
			success: true,
			...parsed,
		});
	} catch (error) {
		console.error("[AI] analyzeImageAI failed:", error.message);

		return res.status(502).json({
			success: false,
			message: "AI analysis failed",
			detail: error.message,
		});
	} finally {
		await safeUnlink(uploadedFile.path);
	}
};

module.exports = {
	analyzeImageAI,
};

