--
-- PostgreSQL database dump
--

\restrict sqwSlLOHwnd4q4AA7AQlfduS5PB2IWfPYtr5B1EyvHgD2t8T3zaf9Tb0YfdDIGR

-- Dumped from database version 17.9 (Homebrew)
-- Dumped by pg_dump version 17.9 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


--
-- Name: block_identity_writes(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.block_identity_writes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  allow TEXT;
BEGIN
  IF NEW.path NOT IN (
    'IDENTITY.md', 'SOUL.md', 'USER.md', 'HEARTBEAT.md', 'CHANNELS.md', 'MEMORY.md'
  ) THEN
    RETURN NEW;
  END IF;

  -- current_setting(missing_ok=true) returns NULL if unset
  allow := current_setting('ironclaw.allow_identity_write', true);

  IF allow IS DISTINCT FROM 'yes' THEN
    RAISE EXCEPTION 'Write rejected: identity file % is protected. Set ironclaw.allow_identity_write=yes within a transaction (SET LOCAL) to override. Used by sync-from-disk.sh only.', NEW.path
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: apps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.apps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    repo text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: customer_people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_people (
    customer_id uuid NOT NULL,
    person_id uuid NOT NULL,
    role text,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    name text NOT NULL,
    aliases text[] DEFAULT '{}'::text[] NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: meetings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meetings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid,
    person_id uuid,
    meeting_id text,
    title text NOT NULL,
    meeting_date date,
    meeting_type text,
    document_id uuid,
    pdf_path text,
    source text DEFAULT 'granola'::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: memory_chunks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memory_chunks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    chunk_index integer NOT NULL,
    content text NOT NULL,
    content_tsv tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, content)) STORED,
    embedding public.vector,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: memory_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memory_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id text NOT NULL,
    agent_id uuid,
    path text NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    customer_id uuid,
    person_id uuid,
    app_id uuid
);


--
-- Name: people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    aliases text[] DEFAULT '{}'::text[] NOT NULL,
    email text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: apps apps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apps
    ADD CONSTRAINT apps_pkey PRIMARY KEY (id);


--
-- Name: apps apps_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apps
    ADD CONSTRAINT apps_slug_key UNIQUE (slug);


--
-- Name: customer_people customer_people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_people
    ADD CONSTRAINT customer_people_pkey PRIMARY KEY (customer_id, person_id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: customers customers_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_slug_key UNIQUE (slug);


--
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (id);


--
-- Name: memory_chunks memory_chunks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_chunks
    ADD CONSTRAINT memory_chunks_pkey PRIMARY KEY (id);


--
-- Name: memory_documents memory_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_documents
    ADD CONSTRAINT memory_documents_pkey PRIMARY KEY (id);


--
-- Name: people people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


--
-- Name: people people_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_slug_key UNIQUE (slug);


--
-- Name: memory_chunks unique_chunk_per_doc; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_chunks
    ADD CONSTRAINT unique_chunk_per_doc UNIQUE (document_id, chunk_index);


--
-- Name: memory_documents unique_path_per_user; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_documents
    ADD CONSTRAINT unique_path_per_user UNIQUE (user_id, agent_id, path);


--
-- Name: idx_apps_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_apps_customer ON public.apps USING btree (customer_id);


--
-- Name: idx_apps_repo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_apps_repo ON public.apps USING btree (lower(repo)) WHERE (repo IS NOT NULL);


--
-- Name: idx_customer_people_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_people_person ON public.customer_people USING btree (person_id);


--
-- Name: idx_meetings_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_meetings_customer ON public.meetings USING btree (customer_id);


--
-- Name: idx_meetings_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_meetings_date ON public.meetings USING btree (meeting_date DESC);


--
-- Name: idx_meetings_meeting_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_meetings_meeting_id ON public.meetings USING btree (meeting_id) WHERE (meeting_id IS NOT NULL);


--
-- Name: idx_meetings_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_meetings_person ON public.meetings USING btree (person_id);


--
-- Name: idx_memory_chunks_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_chunks_document ON public.memory_chunks USING btree (document_id);


--
-- Name: idx_memory_chunks_tsv; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_chunks_tsv ON public.memory_chunks USING gin (content_tsv);


--
-- Name: idx_memory_documents_app; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_documents_app ON public.memory_documents USING btree (app_id);


--
-- Name: idx_memory_documents_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_documents_customer ON public.memory_documents USING btree (customer_id);


--
-- Name: idx_memory_documents_metadata; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_documents_metadata ON public.memory_documents USING gin (metadata jsonb_path_ops);


--
-- Name: idx_memory_documents_path; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_documents_path ON public.memory_documents USING btree (user_id, path);


--
-- Name: idx_memory_documents_path_prefix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_documents_path_prefix ON public.memory_documents USING btree (user_id, path text_pattern_ops);


--
-- Name: idx_memory_documents_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_documents_person ON public.memory_documents USING btree (person_id);


--
-- Name: idx_memory_documents_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_documents_updated ON public.memory_documents USING btree (updated_at DESC);


--
-- Name: idx_memory_documents_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_documents_user ON public.memory_documents USING btree (user_id);


--
-- Name: idx_people_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_people_email ON public.people USING btree (lower(email));


--
-- Name: memory_documents block_identity_writes_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER block_identity_writes_trigger BEFORE INSERT OR UPDATE OF path, content ON public.memory_documents FOR EACH ROW EXECUTE FUNCTION public.block_identity_writes();


--
-- Name: meetings update_meetings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_meetings_updated_at BEFORE UPDATE ON public.meetings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: memory_documents update_memory_documents_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_memory_documents_updated_at BEFORE UPDATE ON public.memory_documents FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: apps apps_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apps
    ADD CONSTRAINT apps_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: customer_people customer_people_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_people
    ADD CONSTRAINT customer_people_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: customer_people customer_people_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_people
    ADD CONSTRAINT customer_people_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.people(id) ON DELETE CASCADE;


--
-- Name: meetings meetings_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- Name: meetings meetings_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.memory_documents(id) ON DELETE SET NULL;


--
-- Name: meetings meetings_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.people(id) ON DELETE SET NULL;


--
-- Name: memory_chunks memory_chunks_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_chunks
    ADD CONSTRAINT memory_chunks_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.memory_documents(id) ON DELETE CASCADE;


--
-- Name: memory_documents memory_documents_app_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_documents
    ADD CONSTRAINT memory_documents_app_id_fkey FOREIGN KEY (app_id) REFERENCES public.apps(id) ON DELETE SET NULL;


--
-- Name: memory_documents memory_documents_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_documents
    ADD CONSTRAINT memory_documents_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: memory_documents memory_documents_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_documents
    ADD CONSTRAINT memory_documents_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.people(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict sqwSlLOHwnd4q4AA7AQlfduS5PB2IWfPYtr5B1EyvHgD2t8T3zaf9Tb0YfdDIGR

