-- Add shared field to notes for public sharing feature
ALTER TABLE notes ADD COLUMN shared BOOLEAN DEFAULT false;
