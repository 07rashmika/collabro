import { Request, Response } from "express";
import { ZodError } from "zod";
import { NotesService } from "./notes.service";
import { AppError }     from "../../common/errors/app-error";
import {
  CreateNoteSchema,
  UpdateNoteSchema,
  NoteQuerySchema,
} from "./notes.schema";

function handleError(res: Response, err: unknown) {
  if (err instanceof ZodError) {
    res.status(400).json({
      message: "Validation failed",
      errors: err.flatten().fieldErrors,
    });
    return;
  }
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ message: err.message });
    return;
  }
  res.status(500).json({ message: (err as Error).message });
}

export class NotesController {
  constructor(private readonly notesService: NotesService) {}

  async getMyNotes(req: Request, res: Response) {
    try {
      const query  = NoteQuerySchema.parse(req.query);
      const result = await this.notesService.getMyNotes(req.user!.sub, query);
      res.status(200).json(result);
    } catch (err) { handleError(res, err); }
  }

  async getPublicNotes(req: Request, res: Response) {
    try {
      const query  = NoteQuerySchema.parse(req.query);
      const result = await this.notesService.getPublicNotes(req.user!.sub, query);
      res.status(200).json(result);
    } catch (err) { handleError(res, err); }
  }

  async getNoteById(req: Request, res: Response) {
  try {
    const note = await this.notesService.getNoteById(req.params.id as string, req.user!.sub);
    res.status(200).json(note);
  } catch (err) { handleError(res, err); }
}

  async createNote(req: Request, res: Response) {
    try {
      const dto  = CreateNoteSchema.parse(req.body);
      const note = await this.notesService.createNote(req.user!.sub, dto);
      res.status(201).json(note);
    } catch (err) { handleError(res, err); }
  }

  async updateNote(req: Request, res: Response) {
    try {
      const dto  = UpdateNoteSchema.parse(req.body);
      const note = await this.notesService.updateNote(req.params.id as string, req.user!.sub, dto);
      res.status(200).json(note);
    } catch (err) { handleError(res, err); }
  }

  async generateSummary(req: Request, res: Response) {
    try {
      const note = await this.notesService.generateSummary(req.params.id as string, req.user!.sub);
      res.status(200).json(note);
    } catch (err) { handleError(res, err); }
  }

  async deleteNote(req: Request, res: Response) {
    try {
      await this.notesService.deleteNote(req.params.id as string, req.user!.sub);
      res.status(204).send();
    } catch (err) { handleError(res, err); }
  }

  async toggleVisibility(req: Request, res: Response) {
    try {
      const note = await this.notesService.toggleVisibility(req.params.id as string, req.user!.sub);
      res.status(200).json(note);
    } catch (err) { handleError(res, err); }
  }

  async getNotesByUser(req: Request, res: Response) {
    try {
      const notes = await this.notesService.getNotesByUser(req.params.userId as string, req.user!.sub);
      res.status(200).json(notes);
    } catch (err) { handleError(res, err); }
  }

  async getAllTags(req: Request, res: Response) {
    try {
      const tags = await this.notesService.getAllTags(req.user!.sub);
      res.status(200).json(tags);
    } catch (err) { handleError(res, err); }
  }

  async uploadPhotos(req: Request, res: Response) {
    try {
      const files = (req.files as Express.Multer.File[] | undefined) ?? [];
      if (files.length === 0) {
        throw new AppError("No photos provided", 400);
      }
      const note = await this.notesService.addPhotos(req.params.id as string, req.user!.sub, files);
      res.status(201).json(note);
    } catch (err) { handleError(res, err); }
  }

  async deletePhoto(req: Request, res: Response) {
    try {
      const note = await this.notesService.deletePhoto(
        req.params.id as string,
        req.params.photoId as string,
        req.user!.sub
      );
      res.status(200).json(note);
    } catch (err) { handleError(res, err); }
  }
}